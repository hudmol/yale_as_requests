class AeonGridRowPopulator

  def initialize(query, resolve_params)
    @query = query
    @resolve_params = resolve_params
    @aeon_grid_rows = []

    perform_search!
  end

  def self.rows_for(query, resolve_params)
    new(query, resolve_params).to_rows
  end

  def to_rows
    @aeon_grid_rows.map{|row| row.to_aeon_grid_row}
  end

  private

  def base_search_params
    base_search_params = {
      :page => 1,
      :page_size => AppConfig.has_key?(:aeon_client_max_results) ? AppConfig[:aeon_client_max_results] : 1000,
    }

    if AppConfig.has_key?(:aeon_client_repo_codes) && !ASUtils.wrap(AppConfig[:aeon_client_repo_codes]).empty?
      repo_query = AdvancedQueryBuilder.new

      repo_lookup = Repository.map {|repo| [repo.repo_code, repo.uri]}.to_h

      ASUtils.wrap(AppConfig[:aeon_client_repo_codes]).each do |repo_code|
        if repo_lookup.has_key?(repo_code)
          repo_query = repo_query.or('repository', repo_lookup.fetch(repo_code), 'text', true)
        else
          raise "repository not found for #{repo_code}"
        end
      end

      base_search_params[:filter] = repo_query.build
    end

    base_search_params
  end

  def call_number_to_resource_uri
    call_number_query = AdvancedQueryBuilder.new.and('identifier', @query, 'text', true)
    search_params = base_search_params.merge({
                                               :type => ['resource'],
                                               :aq => call_number_query.build,
                                             })

    resources = Search.search(search_params, nil).fetch('results', [])

    if resources.length == 1
      resources.first.fetch('id')
    else
      false
    end
  end

  def perform_search!
    # check if call-number
    if (resource_uri = call_number_to_resource_uri)
      return find_in_resource!(resource_uri)
    end

    # find top containers
    container_query = AdvancedQueryBuilder.new
                                          .and('barcode_u_sstr', @query, 'text', true)
                                          .or('title', @query)

    search_params = base_search_params.merge({
                                               :type => ['top_container'],
                                               :aq => container_query.build,
                                             })

    @aeon_grid_rows = Search.search(search_params, nil).fetch('results', [])
                           .map{|result| ContainerRow.new(result) }

    # find archival objects
    ao_query = AdvancedQueryBuilder.new
                                   .and('title', @query, 'text', true)
                                   .or('component_id', @query, 'text', true)
                                   .or('ref_id', @query, 'text', true)
                                   .or('id', @query, 'text', true)
                                   .and('types', 'pui', 'text', true, true)

    search_params = base_search_params.merge({
                                               :type => ['archival_object'],
                                               :aq => ao_query.build,
                                             })

    Search.search(search_params, nil).fetch('results', []).each_slice(16) do |matching_aos|
      ao_jsonmodels = matching_aos.map {|result|
        JSONModel::JSONModel(:archival_object).from_hash(ASUtils.json_parse(result.fetch('json')),
                                              false, true)
      }

      merged_record_hashes = RecordInheritance.merge(URIResolver.resolve_references(ao_jsonmodels, @resolve_params))

      matching_aos.zip(merged_record_hashes).each do |result, inherited_json|
        # identify those that are born digital
        local_access_restriction_types = inherited_json['notes'].select {|n| n['type'] == 'accessrestrict' && n.has_key?('rights_restriction')}
                                                                .map {|n| n['rights_restriction']['local_access_restriction_type']}
                                                                .flatten.uniq

        if local_access_restriction_types.include?('BornDigital')
          @aeon_grid_rows << BornDigitalRow.new(result, inherited_json)

          next
        end

        # map those with container instances
        ASUtils.wrap(result['top_container_uri_u_sstr']).each do |top_container_uri|
          @aeon_grid_rows << ContainerAndItemRow.new(result, inherited_json, top_container_uri)
        end
      end
    end
  end

  def find_in_resource!(uri)
    # find top containers
    container_query = AdvancedQueryBuilder.new.and('collection_uri_u_sstr', uri, 'text', true)

    search_params = base_search_params.merge({
                                               :type => ['top_container'],
                                               :aq => container_query.build,
                                             })

    @aeon_grid_rows = Search.search(search_params, nil).fetch('results', [])
                            .map{|result| ContainerRow.new(result) }


    # find any BornDigital archival objects
    #  - published (contains inherited JSON)
    #  - unpublished
    pui_and_not_query =  AdvancedQueryBuilder.new
                                             .and(AdvancedQueryBuilder.new
                                                                      .and('types', 'pui', 'text', true)
                                                                      .and('publish', 'true', 'text', true))
                                             .or(AdvancedQueryBuilder.new
                                                                     .and('types', 'pui', 'text', true, true)
                                                                     .and('publish', 'false', 'text', true))

    born_digital_query = AdvancedQueryBuilder.new
                                             .and('born_digital_u_sbool', 'true', 'text', true)
                                             .and('resource', uri, 'text', true)
                                             .and(pui_and_not_query)

    search_params = base_search_params.merge({
                                               :type => ['archival_object'],
                                               :aq => born_digital_query.build,
                                             })

    Search.search(search_params, nil).fetch('results', []).each_slice(16) do |matching_aos|
      resolved = URIResolver.resolve_references(
        matching_aos.map {|result|
          JSONModel::JSONModel(:archival_object).from_hash(ASUtils.json_parse(result.fetch('json')), false, true)
        },
        @resolve_params)

      matching_aos.zip(resolved).each do |result, resolved_record|
        @aeon_grid_rows << BornDigitalRow.new(result, resolved_record)
      end
    end
  end

end
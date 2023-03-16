require 'record_inheritance'
require_relative '../../common/aeon_request'

class ArchivesSpaceService < Sinatra::Base

  RecordInheritance.prepare_schemas

  RESOLVE_PARAMS = [
    'repository',
    'resource',
    'top_container',
    'top_container::container_locations',
    'top_container::container_profile',
    'ancestors',
    'linked_agents',
    'ancestors::linked_agents',
    'container_profile',
    'container_locations',
    'active_restrictions::linked_records',
    'instances::digital_object',
  ]

  Endpoint.get('/plugins/aeon_request')
    .description("Map records into an aeon request")
    .params(["uris", [String], "A list of record uris to map"])
    .permissions([])
    .returns([200, "OK"]) \
  do
    out = []

    refs = {}
    params[:uris].each do |uri|
      parsed_uri = JSONModel.parse_reference(uri)
      parsed_repo = JSONModel.parse_reference(parsed_uri[:repository])
      refs[parsed_repo[:id]] ||= {}
      refs[parsed_repo[:id]][parsed_uri[:type]] ||= []
      refs[parsed_repo[:id]][parsed_uri[:type]] << parsed_uri[:id]
    end

    refs.each do |repo_id, types|
      RequestContext.open(:repo_id => repo_id) do
        types.each do |type, ids|
          model = find_model_by_jsonmodel_type(type)
          objs = model.filter(:id => ids).all
          jsons = URIResolver.resolve_references(model.sequel_to_jsonmodel(objs), RESOLVE_PARAMS)
          if RecordInheritance.has_type?(type)
            jsons = jsons.map do |json|
              RecordInheritance.merge(json, :remove_ancestors => true)
            end
          end
          out += jsons
        end
      end
    end

    json_response(out.map{|json| AeonRequest.build(json)})
  end


  Endpoint.get('/plugins/yale_as_requests/search')
          .description("Return results to the Aeon Client")
          .params(['q' , String, "Query string"])
          .permissions([:view_all_records])
          .returns([200, "{}"]) \
  do
    RequestContext.open(:enforce_suppression => true) do
      json_response(:columns => AeonGridRow.column_definitions,
                    :requests => AeonGridRowPopulator.rows_for(params[:q], RESOLVE_PARAMS))
    end
  end


  private

  def find_model_by_jsonmodel_type(type)
    ASModel.all_models.find {|model|
      jsonmodel = model.my_jsonmodel(true)
      jsonmodel && jsonmodel.record_type == type
    }
  end

end

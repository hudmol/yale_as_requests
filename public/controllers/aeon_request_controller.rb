class AeonRequestController < ApplicationController
  def popup
    uri = params[:uri]

    return render status: 400, text: 'uri param required' if uri.nil?

    record = archivesspace.get_record(params[:uri], {
      'resolve[]' => ['repository:id', 'resource:id@compact_resource', 'top_container_uri_u_sstr:id', 'linked_instance_uris:id', 'digital_object_uris:id'],
    })
    mapper = AeonRecordMapper.mapper_for(record)

    return render status: 400, text: 'Action not supported for record' if mapper.hide_button?
    return render status: 400, text: 'Action not available for record' unless mapper.show_action?

    render partial: 'aeon/aeon_request_popup', locals: {
      record: record,
      mapper: mapper,
      request_types: aeon_request_types(mapper),
    }
  end

  def build
    uri = params[:uri]

    return render status: 400, text: 'uri param required' if uri.nil?

    record = archivesspace.get_record(params[:uri], {
      'resolve[]' => ['repository:id', 'resource:id@compact_resource', 'top_container_uri_u_sstr:id', 'linked_instance_uris:id', 'digital_object_uris:id'],
    })
    mapper = AeonRecordMapper.mapper_for(record)

    return render status: 400, text: 'Action not supported for record' if mapper.hide_button?
    return render status: 400, text: 'Action not available for record' unless mapper.show_action?

    request_type_config = aeon_request_types(mapper).detect{|rt| rt.fetch(:request_type) == params[:request_type]}

    return render status: 400, text: "Unknown request type: #{params[:request_type]}" if request_type_config.nil?

    mapper.requested_container_indexes = (params[:instance_idx] || []).map{|idx| Integer(idx)}
    mapper.requested_digital_object_indexes = (params[:digital_instance_idx] || []).map{|idx| Integer(idx)}
    mapper.request_type = request_type_config.fetch(:request_type)

    render partial: 'aeon/aeon_request', locals: {
      record: record,
      mapper: mapper,
      request_type_config: request_type_config,
    }
  end

  private

  def aeon_request_types(mapper)
    [
      {
        :aeon_uri => "#{mapper.repo_settings[:aeon_web_url]}?action=11&type=200",
        :request_type => 'reading_room',
        :button_label => I18n.t('plugins.aeon_fulfillment.request_reading_room_button'),
        :button_help_text => I18n.t('plugins.aeon_fulfillment.request_reading_room_help_text'),
        :extra_params => {'RequestType' => 'Loan'}
      },
      {
        :aeon_uri => "#{mapper.repo_settings[:aeon_web_url]}?action=10&form=23",
        :request_type => 'digitization',
        :button_label => I18n.t('plugins.aeon_fulfillment.request_digital_copy_button'),
        :button_help_text => I18n.t('plugins.aeon_fulfillment.request_digital_copy_help_text'),
        :extra_params => {'RequestType' => 'Copy', 'DocumentType' => 'Default'}
      },
    ]
  end
end

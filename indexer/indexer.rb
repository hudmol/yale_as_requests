class IndexerCommon
  add_indexer_initialize_hook do |indexer|
    indexer.add_document_prepare_hook do |doc, record|
      if doc['primary_type'] == 'archival_object'
        doc['born_digital_u_sbool'] = record['record']['notes'].any? {|note|
          ASUtils.wrap(note.dig('rights_restriction', 'local_access_restriction_type')).include?('BornDigital')
        }
      end
    end
  end
end
require 'db/migrations/utils'

Sequel.migration do

  up do

    # BornDigital enumeration
    born_digital_enum_id = self[:enumeration_value]
                             .filter(:enumeration_id => self[:enumeration].filter(:name => 'restriction_type').select(:id))
                             .filter(:value => 'BornDigital')
                             .select(:id)

    # Is BornDigital a thing?
    return if born_digital_enum_id.count == 0

    # select distinct archival_object_id from `note` where archival_object_id is not null and notes like '%BornDigital%';
    ao_ids_to_reindex = self[:note]
                          .filter(Sequel.~(:archival_object_id) => nil)
                          .filter(Sequel.like(:notes, '%BornDigital%'))
                          .select(:archival_object_id)
                          .distinct

    self[:archival_object]
      .filter(:id => ao_ids_to_reindex)
      .update(:system_mtime => Time.now)
  end

end


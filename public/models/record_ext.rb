class Record
  def build_instance_display_string(instance)
    if sc = instance.fetch('sub_container', nil)
      parse_sub_container_display_string(sc, instance)
    else
      raise "FIXME Digital Object not supported"
    end
  end
end
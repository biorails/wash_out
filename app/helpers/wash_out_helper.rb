module WashOutHelper

  def wsdl_data_options(param)
    case controller.soap_config.wsdl_style
      when 'rpc'
        if param.map.present? || !param.value.nil?
          {:"xsi:type" => param.namespaced_type}
        else
          {:"xsi:nil" => true}
        end
      when 'document'
        {}
    end
  end

  def wsdl_data_attrs(param)
    param.map.reduce({}) do |memo, p|
      if p.respond_to?(:attribute?) && p.attribute?
        memo.merge p.attr_name => p.value
      else
        memo
      end
    end
  end

  def wsdl_data(xml, params)
    params.each do |param|
      next if param.attribute?

      tag_name = param.name
      param_options = wsdl_data_options(param)
      param_options.merge! wsdl_data_attrs(param)

      if param.struct?
        if param.multiplied
          xml.tag! "#{param.array_type}" do

            param.map.each do |p|
              attrs = wsdl_data_attrs p
              if p.is_a?(Array) || p.map.size > attrs.size
                blk = proc { wsdl_data(xml, p.map) }
              end
              attrs.reject! { |_, v| v.nil? }
              xml.tag! tag_name, param_options.merge(attrs), &blk #todo add array level object
            end
          end
        else
          xml.tag! tag_name, param_options do
            wsdl_data(xml, param.map)
          end
        end
      else
        if param.multiplied
          param.value = [] unless param.value.is_a?(Array)
          xml.tag! "#{param.name}_array" do
            param.value.each do |v|
              xml.tag! tag_name, v, param_options
            end
          end
        else
          xml.tag! tag_name, param.value, param_options
        end
      end
    end
  end


  def wsdl_type(xml, param, defined=[])
    more = []
    if param.struct?
      if !defined.include?(param.basic_type)
        wsdl_basic_type(xml, param, defined)
        wsdl_array_type(xml, param)
        defined << param.basic_type
      elsif !param.classified?
        raise RuntimeError, "Duplicate use of `#{param.basic_type}` type name. Consider using classified types."
      end
    end
  end

  def  wsdl_parameter(param)
    if param.multiplied
        {:name => param.name, :type => param.namespaced_type}
     else
        wsdl_occurence(param, false, :name => param.name, :type => param.namespaced_type)
    end
  end

  private
  #
  # .Net soap helper type for array of type
  #
  def wsdl_array_of(xml, param)
    xml.tag! "xsd:element", :name => param.name, :type =>  param.namespaced_type
  end

  def wsdl_basic_type(xml, param, defined)
    more = []
    xml.tag! "xsd:complexType", :name => param.basic_type do
      attrs, elems = [], []
      param.map.each do |value|
        more << value if value.struct?
        if value.attribute?
          attrs << value
        else
          elems << value
        end
      end
      if elems.any?
        xml.tag! "xsd:sequence" do
          elems.each do |value|
            if value.multiplied
              wsdl_array_of(xml, param)
            else
              xml.tag! "xsd:element", wsdl_occurence(value, false, :name => value.name, :type => value.namespaced_type)
            end
          end
        end
      end
      attrs.each do |value|
        xml.tag! "xsd:attribute", wsdl_occurence(value, false, :name => value.attr_name, :type => value.namespaced_type)
      end
    end
    more.each do |p|
      wsdl_type xml, p, defined
    end
  end

=begin
<xsd:complexType name="SoapApi..BiorailsRequestServiceArray">
 <xsd:complexContent>
  <xsd:restriction base="soapenc:Array">
   <xsd:attribute ref="soapenc:arrayType" wsdl:arrayType="typens:SoapApi..BiorailsRequestService[]"/>
  </xsd:restriction>
 </xsd:complexContent>
</xsd:complexType>
=end

  def wsdl_array_type(xml, param)
    xml.tag! "xsd:complexType", :name => param.array_type do
      xml.tag! "xsd:complexContent" do
        xml.tag! "xsd:restriction", base: "soap-enc:Array" do
          xml.tag! "xsd:attribute", {"ref" => "soap-enc:arrayType",
                                     "wsdl:arrayType" => "tns:#{param.basic_type}[]"}
        end
      end
    end
  end

  def wsdl_occurence(param, inject, extend_with = {})
    data = {}  #{"#{'xsi:' if inject}nillable" => 'true'}
    if param.multiplied
      data["#{'xsi:' if inject}minOccurs"] = 0
      data["#{'xsi:' if inject}maxOccurs"] = 'unbounded'
    end
    extend_with.merge(data)
  end

end

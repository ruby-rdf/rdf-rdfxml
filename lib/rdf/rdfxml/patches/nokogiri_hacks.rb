require 'nokogiri'
class Nokogiri::XML::Node
  # URI of namespace + node_name
  def uri
    ns = self.namespace ? self.namespace.href : RDF::XML.to_s
    RDF::URI.intern(ns + self.node_name)
  end
  
  alias_method :attribute_with_ns_without_ffi_null, :attribute_with_ns
  ##
  # Monkey patch attribute_with_ns, to insure nil is returned for #null?
  #
  # Get the attribute node with name and namespace
  #
  # @param [String] name
  # @param [String] namespace
  # @return [Nokogiri::XML::Attr]
  def attribute_with_ns(name, namespace)
    a = attribute_with_ns_without_ffi_null(name, namespace)
    
    (a.respond_to?(:null?) && a.null?) ? nil : a # to ensure FFI Pointer compatibility
  end
end

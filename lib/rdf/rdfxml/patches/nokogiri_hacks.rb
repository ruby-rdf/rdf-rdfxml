require 'nokogiri'
class Nokogiri::XML::Node
  # URI of namespace + node_name
  def uri
    ns = self.namespace ? self.namespace.href : RDF::XML.to_s
    RDF::URI.new(ns + self.node_name)
  end
end unless Nokogiri::XML::Node.method_defined?(:uri)
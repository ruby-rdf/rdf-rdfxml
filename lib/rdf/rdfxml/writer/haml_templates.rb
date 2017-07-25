# Default HAML templates used for generating RDF/XML output from the writer
module RDF::RDFXML
  class Writer
    # The default set of HAML templates used for RDFa code generation
   BASE_HAML = {
     identifier: "base", 
      # Document
      # Locals: lang, title, prefix, base, subjects
      # Yield: subjects.each
      doc: %q(
        = %(<?xml version='1.0' encoding='utf-8' ?>)
        - if stylesheet
          = %(<?xml-stylesheet type="text/xsl" href="#{stylesheet}"?>)
        %rdf:RDF{prefix_attrs.merge("xml:lang" => lang, "xml:base" => base)}
          - subjects.each do |subject|
            != yield(subject)
      ),

      # Output for non-leaf resources
      # Note that @about may be omitted for Nodes that are not referenced
      #
      # If _rel_ and _resource_ are not nil, the tag will be written relative
      # to a previous subject. If _element_ is :li, the tag will be written
      # with <li> instead of <div>.
      #
      # Locals: subject, typeof, predicates, rel, element, inlist, attr_props
      # Yield: predicates.each
      subject: %q(
        - first_type, *types = typeof.to_s.split(' ')
        - (types.unshift(first_type); first_type = nil) if first_type && (first_type.include?('/') || first_type.start_with?('_:'))
        - first_type ||= get_qname(RDF.Description)
        - first_type = first_type[1..-1] if first_type.to_s.start_with?(":")
        - attr_props = attr_props.merge(get_qname(RDF.nodeID) => subject.id) if subject.node? && ref_count(subject) >= 1
        - attr_props = attr_props.merge(get_qname(RDF.about) => relativize(subject)) if subject.uri?
        - haml_tag(first_type, attr_props) do
          - types.each do |type|
            - expanded_type = expand_curie(type)
            - if expanded_type.start_with?('_:')
              - haml_tag(get_qname(RDF.type), "rdf:nodeID" => expanded_type[2..-1])
            -else
              - haml_tag(get_qname(RDF.type), "rdf:resource" => expanded_type)
          - predicates.each do |p|
            = yield(p)
      ),

      # Output for single-valued properties
      # Locals: predicate, object, inlist
      # Yields: object
      # If nil is returned, render as a leaf
      # Otherwise, render result
      property_value: %q(
      - if recurse && res = yield(object)
        - haml_tag(property) do
          = res
      - elsif object.literal? && object.datatype == RDF.XMLLiteral
        - haml_tag(property, :"<", "rdf:parseType" => "Literal") do
          = object.value
      - elsif object.literal?
        - haml_tag(property, :"<", "xml:lang" => object.language, "rdf:datatype" => (object.datatype unless object.plain?)) do
          = object.value.to_s.encode(xml: :text)
      - elsif object.node?
        - haml_tag(property, :"/", "rdf:nodeID" => object.id)
      - else
        - haml_tag(property, :"/", "rdf:resource" => relativize(object))
      ),

      # Outpust for a list
      # Locals: predicate, list
      # Yields: object
      # If nil is returned, render as a leaf
      # Otherwise, render result
      collection: %q(
        - haml_tag(property, get_qname(RDF.parseType) => "Collection") do
          - list.each do |object|
            - if recurse && res = yield(object)
              = res
            - elsif object.node?
              - haml_tag(get_qname(RDF.Description), :"/", "rdf:nodeID" => (object.id if ref_count(object) > 1))
            - else
              - haml_tag(get_qname(RDF.Description), :"/", "rdf:about" => relativize(object))
      ),
    }
    HAML_TEMPLATES = {base: BASE_HAML}
    DEFAULT_HAML = BASE_HAML
  end
end
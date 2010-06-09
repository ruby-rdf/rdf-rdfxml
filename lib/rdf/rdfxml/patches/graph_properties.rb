module RDF
  class Graph
    # Resource properties
    #
    # Properties arranged as a hash with the predicate Term as index to an array of resources or literals
    #
    # Example:
    #   graph.load(':foo a :bar; rdfs:label "An example" .', "http://example.com/")
    #   graph.resources(URI.new("http://example.com/subject")) =>
    #   {
    #     "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" => [<http://example.com/#bar>],
    #     "http://example.com/#label"                       => ["An example"]
    #   }
    def properties(subject, recalc = false)
      @properties ||= {}
      @properties.delete(subject.to_s) if recalc
      @properties[subject.to_s] ||= begin
        hash = Hash.new
        self.query(:subject => subject) do |statement|
          pred = statement.predicate.to_s

          hash[pred] ||= []
          hash[pred] << statement.object
        end
        hash
      end
    end
  end
end
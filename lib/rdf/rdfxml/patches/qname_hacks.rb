module RDF
  class URI
    #unless defined?(:vocab)
      def vocab
        # Find vocabulary if not assigned
        return @vocab if @vocab
        
        Vocabulary.each do |vocab|
          return @vocab = vocab if to_s.index(vocab.to_uri.to_s) == 0
        end
      end
    
      def vocab=(value)
        @vocab = value
      end
      
      def qname
        @qname ||= if vocab
          vocab_name = vocab.__name__.split('::').last.downcase
          local_name = to_s[vocab.to_uri.to_s.size..-1]
          vocab_name && local_name && [vocab_name.to_sym, local_name.to_sym]
        end
      end
    #end
  end
  
  class Vocabulary
    def self.[](property)
      @prop_uri ||= {}
      @prop_uri[property] ||= begin
        uri = RDF::URI.new([to_s, property.to_s].join(''))
        uri.vocab = self
        uri
      end
    end

    def [](property)
      @prop_uri ||= {}
      @prop_uri[property] ||= begin
        uri = RDF::URI.new([to_s, property.to_s].join(''))
        uri.vocab = self
        uri
      end
    end
    
    def to_uri
      @uri ||= begin
        uri = RDF::URI.new(to_s)
        uri.vocab = self
        uri
      end
    end
  end
end
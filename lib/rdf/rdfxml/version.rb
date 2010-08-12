module RDF::RDFXML::VERSION
  MAJOR = 0
  MINOR = 2
  TINY  = 2
  EXTRA = 1

  STRING = [MAJOR, MINOR, TINY].join('.')
  STRING << ".#{EXTRA}" if EXTRA

  ##
  # @return [String]
  def self.to_s()   STRING end

  ##
  # @return [String]
  def self.to_str() STRING end

  ##
  # @return [Array(Integer, Integer, Integer)]
  def self.to_a() [MAJOR, MINOR, TINY] end
end

require 'rspec/matchers'

RSpec::Matchers.define :have_xpath do |path, value, namespaces, logger|
  match do |actual|
    root = RDF::RDFXML::Reader.new(actual).root
    return false unless root
    namespaces = root.namespaces.inject({}) {|memo, (k,v)| memo[k.to_s.sub(/xmlns:?/, '')] = v; memo}.
      merge(namespaces).
      merge("xhtml" => "http://www.w3.org/1999/xhtml", "xml" => "http://www.w3.org/XML/1998/namespace")
    @result = root.at_xpath(path, namespaces) rescue false
    case value
    when false
      @result.nil?
    when true
      !@result.nil?
    when Array
      @result.to_s.split(" ").include?(*value)
    when Regexp
      @result.to_s =~ value
    else
      @result.to_s == value
    end
  end

  failure_message do |actual|
    msg = "expected that #{path.inspect}\nwould be: #{value.inspect}"
    msg += "\n     was: #{@result}"
    msg += "\nsource:" + actual
    msg +=  "\nDebug:#{logger}" 
    msg
  end

  failure_message_when_negated do |actual|
    msg = "expected that #{path.inspect}\nwould not be #{value.inspect}"
    msg += "\nsource:" + actual
    msg +=  "\nDebug:#{logger}"
    msg
  end
end

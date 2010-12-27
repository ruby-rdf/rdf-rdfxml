$:.unshift "."
require File.join(File.dirname(__FILE__), 'spec_helper')
require 'rdf/rdfxml/patches/graph_properties'

class EX < RDF::Vocabulary("http://example.com/"); end

describe RDF::Graph do
  describe "properties" do
    subject { RDF::Graph.new }
    
    it "should get asserted properties" do
      subject << [EX.a, EX.b, EX.c]
      subject.properties(EX.a).should be_a(Hash)
      subject.properties(EX.a).size.should == 1
      subject.properties(EX.a).has_key?(EX.b.to_s).should be_true
      subject.properties(EX.a)[EX.b.to_s].should == [EX.c]
    end
    
    it "should get asserted properties with 2 properties" do
      subject << [EX.a, EX.b, EX.c]
      subject << [EX.a, EX.b, EX.d]
      subject.properties(EX.a).should be_a(Hash)
      subject.properties(EX.a).size.should == 1
      subject.properties(EX.a).has_key?(EX.b.to_s).should be_true
      subject.properties(EX.a)[EX.b.to_s].should include(EX.c, EX.d)
    end

    it "should get asserted properties with 3 properties" do
      subject << [EX.a, EX.b, EX.c]
      subject << [EX.a, EX.b, EX.d]
      subject << [EX.a, EX.b, EX.e]
      subject.properties(EX.a).should be_a(Hash)
      subject.properties(EX.a).size.should == 1
      subject.properties(EX.a).has_key?(EX.b.to_s).should be_true
      subject.properties(EX.a)[EX.b.to_s].should include(EX.c, EX.d, EX.e)
    end
    
    it "should get asserted properties for a RDF::Node" do
      bn = RDF::Node.new
      subject << [bn, EX.b, EX.c]
      subject.properties(bn).should be_a(Hash)
      subject.properties(bn).size.should == 1
      subject.properties(bn).has_key?(EX.b.to_s).should be_true
      subject.properties(bn)[EX.b.to_s].should == [EX.c]
    end

    it "should get asserted type with single type" do
      subject << [EX.a, RDF.type, EX.Audio]
      subject.properties(EX.a)[RDF.type.to_s].should == [EX.Audio]
      subject.type_of(EX.a).should == [EX.Audio]
    end
  
    it "should get nil with no type" do
      subject << [EX.a, EX.b, EX.c]
      subject.properties(EX.a)[RDF.type.to_s].should == nil
      subject.type_of(EX.a).should == []
    end
  end
end
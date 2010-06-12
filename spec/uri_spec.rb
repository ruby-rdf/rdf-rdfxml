# coding: utf-8
require File.join(File.dirname(__FILE__), 'spec_helper')

describe RDF::URI do
  subject { RDF::URI.new("http://example.org")}
  
  context "join" do
    it "should append fragment to uri" do
      subject.join("foo").to_s.should == "http://example.org/foo"
    end

    it "should append another fragment" do
      subject.join("foo#bar").to_s.should == "http://example.org/foo#bar"
    end

    it "should append another URI" do
      subject.join(RDF::URI.new("foo#bar")).to_s.should == "http://example.org/foo#bar"
    end

    describe "normalization" do
      {
        %w(http://foo ) =>  "http://foo/",
        %w(http://foo a) => "http://foo/a",
        %w(http://foo /a) => "http://foo/a",
        %w(http://foo #a) => "http://foo/#a",

        %w(http://foo/ ) =>  "http://foo/",
        %w(http://foo/ a) => "http://foo/a",
        %w(http://foo/ /a) => "http://foo/a",
        %w(http://foo/ #a) => "http://foo/#a",

        %w(http://foo# ) =>  "http://foo/", # Special case for Addressable
        %w(http://foo# a) => "http://foo/a",
        %w(http://foo# /a) => "http://foo/a",
        %w(http://foo# #a) => "http://foo/#a",

        %w(http://foo/bar ) =>  "http://foo/bar",
        %w(http://foo/bar a) => "http://foo/a",
        %w(http://foo/bar /a) => "http://foo/a",
        %w(http://foo/bar #a) => "http://foo/bar#a",

        %w(http://foo/bar/ ) =>  "http://foo/bar/",
        %w(http://foo/bar/ a) => "http://foo/bar/a",
        %w(http://foo/bar/ /a) => "http://foo/a",
        %w(http://foo/bar/ #a) => "http://foo/bar/#a",

        %w(http://foo/bar# ) =>  "http://foo/bar",
        %w(http://foo/bar# a) => "http://foo/a",
        %w(http://foo/bar# /a) => "http://foo/a",
        %w(http://foo/bar# #a) => "http://foo/bar#a",

        %w(http://foo/bar# #D%C3%BCrst) => "http://foo/bar#D%C3%BCrst",
        %w(http://foo/bar# #Dürst) => "http://foo/bar#D%C3%BCrst",
      }.each_pair do |input, result|
        it "should create <#{result}> from <#{input[0]}> and '#{input[1]}'" do
          RDF::URI.new(input[0]).join(input[1].to_s).normalize.to_s.should == result
        end
      end
    end
  end
end

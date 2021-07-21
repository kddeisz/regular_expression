# frozen_string_literal: true

require "graphviz"
require "json"
require "regular_expression"
require "sinatra/base"
require_relative "ui"

class App < Sinatra::Base
  get "/" do
    erb :index
  end

  post "/" do
    body = request.body.read
    return status(400) if body.empty?

    data = JSON.parse(body, symbolize_names: true)
    return status(400) if !valid?(data, :pattern) || !valid?(data, :value)

    @ui = result(data)
    erb :result
  end

  private

  def valid?(data, key)
    !data[key].nil? && !data[key].strip.empty?
  end

  def match(pattern:, value:)
    pattern = RegularExpression::Pattern.new(pattern)
    !pattern.match?(value).nil?
  end

  def graph(pattern)
    graphviz = Graphviz::Graph.new
    RegularExpression::Parser.new.parse(pattern).to_dot(graphviz)
    svg = Graphviz.output(graphviz, format: "svg")
    svg[svg.index("<!-- Generated by graphviz")..]
  end

  def result(data)
    return UI::NO_MATCH unless match(**data)

    UI::Match.new(graph: graph(data[:pattern]))
  rescue Racc::ParseError
    UI::ERROR
  end
end

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "ruby/signature"
require "tmpdir"
require 'minitest/reporters'

MiniTest::Reporters.use!

module TestHelper
  def parse_type(string, variables: Set.new)
    Ruby::Signature::Parser.parse_type(string, variables: variables)
  end

  def type_name(string)
    Ruby::Signature::Namespace.parse(string).yield_self do |namespace|
      last = namespace.path.last
      Ruby::Signature::TypeName.new(name: last, namespace: namespace.parent)
    end
  end

  class SignatureManager
    attr_reader :files

    def initialize
      @files = {}

      files[Pathname("builtin.rbi")] = BUILTINS
    end

    def self.new
      instance = super

      if block_given?
        yield instance
      else
        instance
      end
    end

    BUILTINS = <<SIG
class BasicObject
  def __id__: -> Integer

  private
  def initialize: -> void
end

class Object < BasicObject
  include Kernel
 
  public
  def __id__: -> Integer

  private
  def respond_to_missing?: (Symbol, bool) -> bool
end

module Kernel
  private
  def puts: (*any) -> nil
end

class Class < Module
end

class Module
end

class String
  include Comparable
  prepend Enumerable[String, void]

  def self.try_convert: (any) -> String?
end

class Integer
end

class Symbol
end

module Comparable
end

module Enumerable[A, B]
end
SIG

    def add_file(path, content)
      files[Pathname(path)] = content
    end

    def build
      Dir.mktmpdir do |tmpdir|
        tmppath = Pathname(tmpdir)

        files.each do |path, content|
          absolute_path = tmppath + path
          absolute_path.parent.mkpath
          absolute_path.write(content)
        end

        env = Ruby::Signature::Environment.new()
        loader = Ruby::Signature::EnvironmentLoader.new(env: env)
        loader.stdlib_root = nil
        loader.add path: tmppath
        loader.load

        yield env
      end
    end
  end
end

require "minitest/autorun"

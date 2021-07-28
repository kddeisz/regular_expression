# frozen_string_literal: true

require_relative "./test_helper"

require_relative "./mspec"
require_relative "./known_failures"

require_relative "../spec/language/fixtures/classes"

module RegularExpression
  # Patch string so that it can match against our own regexp classes. We're only
  # going to do this in tests as I don't want to actually monkey-patch string
  # with our library.
  module StringExtension
    def match(pattern)
      pattern.is_a?(Pattern) ? pattern.match(self) : super
    end
  end
end

String.prepend(RegularExpression::StringExtension)
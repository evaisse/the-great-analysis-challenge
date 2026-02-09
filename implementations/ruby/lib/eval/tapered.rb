# frozen_string_literal: true

module Chess
  module Eval
    module Tapered
      def self.interpolate(mg_score, eg_score, phase)
        (mg_score * phase + eg_score * (256 - phase * 10 - 16)) / 256
      end
    end
  end
end

# == Schema Information
#
# Table name: markov_trigrams
#
#  id          :integer          not null, primary key
#  source_type :string(255)      not null
#  prefix      :string(255)      default(""), not null
#  others_json :text(4294967295) not null
#  state       :integer          default("normal"), not null
#
# Indexes
#
#  index_markov_trigrams_on_prefix_and_state  (prefix,state) UNIQUE
#

require 'test_helper'

class MarkovTrigramTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

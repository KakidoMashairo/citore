# == Schema Information
#
# Table name: citore_erotic_images
#
#  id         :integer          not null, primary key
#  keyword    :string(255)      not null
#  file_name  :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_citore_erotic_images_on_keyword  (keyword)
#

require 'test_helper'

class Citore::EroticImageTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

# == Schema Information
#
# Table name: datapool_video_meta
#
#  id                :integer          not null, primary key
#  type              :string(255)
#  title             :string(255)      not null
#  front_image_url   :text(65535)
#  data_category     :integer          default("file"), not null
#  bitrate           :integer          default(0), not null
#  origin_src        :string(255)      not null
#  query             :text(65535)
#  options           :text(65535)
#  original_filename :string(255)
#
# Indexes
#
#  index_datapool_video_meta_on_origin_src  (origin_src)
#  index_datapool_video_meta_on_title       (title)
#

require 'test_helper'

class Datapool::VideoMetumTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end

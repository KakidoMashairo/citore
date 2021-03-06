# == Schema Information
#
# Table name: datapool_audio_tracks
#
#  id             :bigint(8)        not null, primary key
#  type           :string(255)
#  audio_metum_id :integer
#  title          :string(255)      not null
#  track_id       :string(255)      not null
#  isrc           :string(255)
#  duration       :float(24)        default(0.0), not null
#  url            :string(255)
#  album_ids      :text(65535)
#  options        :text(65535)
#
# Indexes
#
#  index_datapool_audio_tracks_on_audio_metum_id     (audio_metum_id)
#  index_datapool_audio_tracks_on_isrc               (isrc)
#  index_datapool_audio_tracks_on_track_id_and_type  (track_id,type) UNIQUE
#

class Datapool::AudioTrack < ApplicationRecord
  has_many :elements, as: :audio, class_name: 'Datapool::AudioElement'
  has_one :detail, class_name: 'Datapool::AudioTrackDetail'

  belongs_to :metum, class_name: 'Datapool::AudioMetum', foreign_key: :audio_metum_id, required: false

  serialize :album_ids, JSON
  serialize :options, JSON
end

namespace :crawl do
  task wikipedia_article: :environment do
    last_page_id = WikipediaArticle.maximum(:wikipedia_page_id).to_i
    WikipediaPage.where("id > ?", last_page_id).where(is_redirect: false).find_each do |page|
      next if WikipediaArticle.exists?(wikipedia_page_id: page.id)
      begin
        article_json = WikipediaArticle.get_article(page.title)
        next if article_json["query"]["pages"][page.id.to_s].blank?
        article_rev = article_json["query"]["pages"][page.id.to_s]["revisions"].first
        next if article_rev.blank?
        doc = Nokogiri::HTML.parse(article_rev["*"])
        WikipediaArticle.create!(
          wikipedia_page_id: page.id,
          title: article_json["query"]["pages"][page.id.to_s]["title"],
          body: Sanitizer.basic_sanitize(doc.css("p").text)
        )
      rescue
        sleep 1
      end
    end
  end

  task generate_target: :environment do
    #Lyric.generate_utanet_taget!
    Lyric.generate_jlyric_taget!
  end

  task lyric_html: :environment do
    CrawlTargetUrl.execute_html_crawl!(Lyric.to_s) do |crawl_target, doc|
#      lyric = Lyric.generate_by_utanet!(crawl_target.crawl_from_keyword, doc)
      lyric = Lyric.generate_by_jlyric!(doc)
      crawl_target.source_id = lyric.id
    end
  end

  task categorised_word_html: :environment do
    large_jas = {}
    medium_jas = {}
    larges = CategorisedWord.large_categories
    larges.each do |k, v|
      large_jas[I18n.t("activerecord.enum.categorised_word.large_category.#{k}")] = v
    end

    mediums = CategorisedWord.medium_categories
    mediums.each do |k, v|
      medium_jas[I18n.t("activerecord.enum.categorised_word.medium_category.#{k}")] = v
    end
    url_text = RequestParser.request_and_get_links_from_html(url: ExpressionCategorisedWord::JAPANESE_HYOGEN_URL)
    CrawlTargetUrl.execute_html_crawl!(ExpressionCategorisedWord.to_s) do |crawl_target, doc|
      from_doc = RequestParser.request_and_parse_html(url: crawl_target.crawl_from_keyword)
      detail = from_doc.css("a").detect{|h| h[:href] == crawl_target.crawl_from_keyword }
      large_text = from_doc.css(".pan_anchor")[1].try(:text).to_s
      t, value = large_jas.detect{|k, v| large_text.include?(k.to_s) }

      words = doc.css(".item2").map{|i| i.text }
      models = words.map do |w|
        ExpressionCategorisedWord.new({
          type: ExpressionCategorisedWord.to_s,
          large_category: value,
          medium_category: medium_jas[url_text[crawl_target.crawl_from_keyword]],
          detail_category: detail.try(:text).to_s,
          body: Sanitizer.basic_sanitize(w)
        })
      end
      ExpressionCategorisedWord.import(models)
      crawl_target.source_id = ExpressionCategorisedWord.last.id
    end
    DicExpressionWord.generate_record!
  end

  task youtube: :environment do
    stay_id = ExtraInfo.read_extra_info["crawl_category_id"]
    YoutubeCategory.guide.where("id > ?", stay_id.to_i).find_each do |guide_category|
      YoutubeChannel.crawl_loop_request do |youtube, page_token|
        youtube_channel = youtube.list_channels("id,snippet,statistics", max_results: 50, category_id: guide_category.category_id, page_token: page_token)
        YoutubeChannel.import_channel!(youtube_channel, category_id: guide_category.id)
        youtube_channel
      end
      ExtraInfo.update({"crawl_category_id" => guide_category.id})
    end

    stay_id = ExtraInfo.read_extra_info["crawl_channel_video_id"]
    YoutubeChannel.where("id > ?", stay_id.to_i).find_each do |channel|
      YoutubeVideo.crawl_loop_request do |youtube, page_token|
        youtube_search = youtube.list_searches("id,snippet", max_results: 50, region_code: "JP",  type: "video", channel_id: channel.channel_id, page_token: page_token)
        youtube_video = youtube.list_videos("id,snippet,statistics", max_results: 50, id: youtube_search.items.map{|item| item.id.video_id}.join(","))
        YoutubeVideo.import_video!(youtube_video, channel_id: channel.id)
        youtube_search
      end
      ExtraInfo.update({"crawl_channel_video_id" => channel.id})
    end

    stay_id = ExtraInfo.read_extra_info["crawl_category_video_id"]
    YoutubeCategory.where("id > ?", stay_id.to_i).video.find_each do |video_category|
      YoutubeVideo.crawl_loop_request do |youtube, page_token|
        youtube_search = youtube.list_searches("id,snippet", max_results: 50, region_code: "JP",  type: "video", video_category_id: video_category.category_id, page_token: page_token)
        youtube_video = youtube.list_videos("id,snippet,statistics", max_results: 50, id: youtube_search.items.map{|item| item.id.video_id}.join(","))
        YoutubeVideo.import_video!(youtube_video, category_id: video_category.id)
        youtube_search
      end
      ExtraInfo.update({"crawl_category_video_id" => video_category.id})
    end

    info = ExtraInfo.read_extra_info
    stay_id = info["crawl_related_video_id"]
    youtube_last_video = YoutubeVideo.last
    ExtraInfo.update({"related_max_id" => youtube_last_video.id}) if info["related_max_id"].blank?
    YoutubeVideo.where("id > ?", stay_id.to_i).find_each do |video|
      YoutubeVideo.crawl_loop_request do |youtube, page_token|
        youtube_search = youtube.list_searches("id,snippet", max_results: 50, region_code: "JP",  type: "video", related_to_video_id: video.video_id, page_token: page_token)
        if youtube_search.items.present?
          youtube_video = youtube.list_videos("id,snippet,statistics", max_results: 50, id: youtube_search.items.map{|item| item.id.video_id}.join(","))
          video.import_related_video!(youtube_video)
        end
        youtube_search
      end
      ExtraInfo.update({"crawl_related_video_id" => video.id})
    end

    youtube = Google::Apis::YoutubeV3::YouTubeService.new
    youtube.key = ENV.fetch('GOOGLE_API_KEY', '')

    stay_id = ExtraInfo.read_extra_info["rebuild_video_id"]
    YoutubeVideo.where("id > ?", stay_id.to_i).find_in_batches({batch_size: 50}) do |videos|
      youtube_video = youtube.list_videos("id,snippet", max_results: 50, id: videos.map{|video| video.video_id}.join(","))
      id_and_tags = {}
      youtube_video.items.each do |item|
        id_and_tags[item.id] = item.snippet.tags
      end
      YoutubeVideoTag.where(youtube_video_id: videos.map(&:id)).delete_all
      YoutubeVideo.import_tags(id_and_tags)
      ExtraInfo.update({"rebuild_video_id" => videos.max_by{|v| v.id }.try(:id)})
    end

    stay_id = ExtraInfo.read_extra_info["crawl_channel_comment_id"]
    YoutubeChannel.where("comment_count > 0 AND id > ?", stay_id.to_i).find_each do |channel|
      YoutubeComment.crawl_loop_request do |youtube, page_token|
        youtube_comment_thread = youtube.list_comment_threads("id,snippet", max_results: 100, channel_id: channel.channel_id, page_token: page_token, text_format: "plainText")

        YoutubeComment.import_comment!(youtube_comment_thread, channel_id: channel.id)
        youtube_comment_thread
      end
      ExtraInfo.update({"crawl_channel_comment_id" => channel.id})
    end

    stay_id = ExtraInfo.read_extra_info["crawl_video_comment_id"]
    YoutubeVideo.where("comment_count > 0 AND id > ?", stay_id.to_i).find_each do |video|
      YoutubeVideo.crawl_loop_request do |youtube, page_token|
        youtube_comment_thread = youtube.list_comment_threads("id,snippet", max_results: 100, video_id: video.video_id, page_token: page_token, text_format: "plainText")
        YoutubeComment.import_comment!(youtube_comment_thread, video_id: video.id)
        youtube_comment_thread
      end
      ExtraInfo.update({"crawl_video_comment_id" => channel.id})
    end

#    response = youtube.list_videos("id,snippet,contentDetails,liveStreamingDetails,player,recordingDetails,statistics,status,topicDetails", max_results: 50, id: YoutubeVideo.limit(50).pluck(:video_id).join(","))
#    response = youtube.list_comment_threads("id,snippet,replies", max_results: 100, video_id: "0E00Zuayv9Q")
#    response = youtube.list_comment_threads("id,snippet,replies", max_results: 100, video_id: "YIF2mSTNtEc")
#    response = youtube.list_searches("id,snippet", max_results: 50, region_code: "JP", q: "PPAP",  type: "video", video_category_id: nil, channel_id: nil)
#    response = youtube.list_channels("id,snippet,statistics,brandingSettings", max_results: 50, category_id: "GCQmVzdCBvZiBZb3VUdWJl")
    #response = youtube.list_guide_categories("id,snippet", region_code: "JP", hl: "ja_JP")
#    response.items
#    p response.to_h
  end

  task rebuild_youtube_video_tags: :environment do
    youtube = Google::Apis::YoutubeV3::YouTubeService.new
    youtube.key = ENV.fetch('GOOGLE_API_KEY', '')

    stay_id = ExtraInfo.read_extra_info["rebuild_video_id"]
    YoutubeVideo.where("id > ?", stay_id.to_i).find_in_batches({batch_size: 50}) do |videos|
      youtube_video = youtube.list_videos("id,snippet", max_results: 50, id: videos.map{|video| video.video_id}.join(","))
      id_and_tags = {}
      youtube_video.items.each do |item|
        id_and_tags[item.id] = item.snippet.tags
      end
      YoutubeVideoTag.where(youtube_video_id: videos.map(&:id)).delete_all
      YoutubeVideo.import_tags(id_and_tags)
      ExtraInfo.update({"rebuild_video_id" => videos.max_by{|v| v.id }.try(:id)})
    end
  end

  task youtube_download: :environment do
    YoutubeDL.download "https://www.youtube.com/watch?v=0E00Zuayv9Q", output: 'some_file.mp4'
  end
end
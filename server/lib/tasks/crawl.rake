namespace :crawl do
  task wikipedia_article: :environment do
    WikipediaPage.where(is_redirect: false).find_each do |page|
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
          body: WikipediaArticle.sanitize(doc.css("p").text)
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
    CrawlTargetUrl.execute_html_crawl! do |crawl_target, doc|
      lyric = Lyric.generate_by_utanet(crawl_target.crawl_from_keyword, doc)
      crawl_target.source_id = lyric.id
    end
  end

  task youtube: :environment do
#    apiconfig = YAML.load(File.open(Rails.root.to_s + "/config/apiconfig.yml"))
#    youtube = Google::Apis::YoutubeV3::YouTubeService.new
#    youtube.key = apiconfig["google_api"]["key"]

    YoutubeCategory.guide.find_each do |guide_category|
      YoutubeChannel.crawl_loop_request do |youtube, page_token|
        youtube_channel = youtube.list_channels("id,snippet,statistics,brandingSettings", max_results: 50, category_id: guide_category.category_id, page_token: page_token)
        channels = youtube_channel.items.map do |item|
          cannel = YoutubeChannel.new(
            youtube_category_id: guide_category.id,
            channel_id: item.id,
            title: item.snippet.title,
            description: item.snippet.description,
            published_at: item.snippet.published_at,
            thumnail_image_url: item.snippet.thumbnails.default.url,
            comment_count: item.statistics.comment_count,
            subscriber_count: item.statistics.subscriber_count,
            video_count: item.statistics.video_count,
            view_count: item.statistics.view_count,
            banner_image_url_json: item.branding_settings.image.to_json
          )
          cannel
        end
        YoutubeChannel.import(channels)
        youtube_channel
      end
    end

#    response = youtube.list_comment_threads("id,snippet,replies", max_results: 100, video_id: "YIF2mSTNtEc")
#    response = youtube.list_searches("id,snippet", max_results: 50, region_code: "JP", q: "PPAP")
#    response = youtube.list_channels("id,snippet,statistics,brandingSettings", max_results: 50, category_id: "GCQmVzdCBvZiBZb3VUdWJl")
    #response = youtube.list_guide_categories("id,snippet", region_code: "JP", hl: "ja_JP")
#    response.items
#    p response.to_h
  end

  task import_sql_from_wikipedia: :environment do
    [
        [WikipediaTopicCategory, "jawiki-latest-category.sql.gz"],
        [WikipediaPage, "jawiki-latest-page.sql.gz"]
#        [WikipediaCategoryPage, "jawiki-latest-categorylinks.sql.gz"]
    ].each do |clazz, file_name|
      puts "#{clazz.table_name} download start"
      gz_file_path = clazz.download_file(file_name)
      puts "#{clazz.table_name} decompress start"
      query_string = clazz.decompress_gz_query_string(gz_file_path)
      puts "#{clazz.table_name} save file start"
      sanitized_query = clazz.try(:sanitized_query, query_string) || query_string
      decompressed_file_path = gz_file_path.gsub(".gz", "")
      File.open(decompressed_file_path, 'wb'){|f| f.write(sanitized_query) }
      puts "#{clazz.table_name} import data start"
      clazz.import_dump_query(decompressed_file_path)
      clazz.remove_file(gz_file_path)
      clazz.remove_file(decompressed_file_path)
      puts "#{clazz.table_name} import completed"
    end
  end

  task youtube_download: :environment do
    YoutubeDL.download "https://www.youtube.com/watch?v=0E00Zuayv9Q", output: 'some_file.mp4'
  end
end
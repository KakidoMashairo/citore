class Tools::ImageCrawlController < Homepage::BaseController
  before_action :load_upload_jobs, only: [:url, :twitter, :flickr]
  before_action :execute_upload_job, only: [:url_crawl, :twitter_crawl, :flickr_crawl]

  def index
  end

  def twitter
  end

  def twitter_crawl
    render :json => @upload_job.to_json
  end

  def flickr
  end

  def flickr_crawl
    render :json => @upload_job.to_json
  end

  def url
  end

  def url_crawl
    render :json => @upload_job.to_json
  end

  private
  def load_upload_jobs
    @upload_jobs = @visitor.upload_jobs
  end

  def execute_upload_job
    if params[:action] == "flickr_crawl"
      @upload_job = @visitor.upload_jobs.create!(from_type: "Datapool::FrickrImageMetum", token: SecureRandom.hex)
    elsif params[:action] == "twitter_crawl"
      @upload_job = @visitor.upload_jobs.create!(from_type: "Datapool::TwitterImageMetum", token: SecureRandom.hex)
    else
      @upload_job = @visitor.upload_jobs.create!(from_type: "Datapool::WebSiteImageMetum", token: SecureRandom.hex)
    end
    ImageCrawlJob.perform_later(params.dup, @upload_job)
  end
end
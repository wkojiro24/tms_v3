class KnowledgeArticlesController < ApplicationController
  before_action :set_article, only: [:show]

  def index
    @articles = current_tenant.knowledge_articles.published.ordered
    @articles_by_category = @articles.group_by(&:category)

    if params[:category].present?
      @articles = @articles.by_category(params[:category])
    end

    if params[:q].present?
      query = "%#{params[:q]}%"
      @articles = @articles.where("title LIKE ? OR body LIKE ?", query, query)
    end
  end

  def show
    @article.increment_view_count!
  end

  private

  def set_article
    @article = current_tenant.knowledge_articles.published.find_by!(slug: params[:id])
  rescue ActiveRecord::RecordNotFound
    @article = current_tenant.knowledge_articles.published.find(params[:id])
  end
end

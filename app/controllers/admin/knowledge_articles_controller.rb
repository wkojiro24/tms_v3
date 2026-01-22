module Admin
  class KnowledgeArticlesController < ApplicationController
    before_action :set_article, only: [:show, :edit, :update, :destroy, :publish, :unpublish]

    def index
      @articles = current_tenant.knowledge_articles.ordered
      @articles_by_category = @articles.group_by(&:category)
    end

    def show
    end

    def new
      @article = current_tenant.knowledge_articles.build
      @article.category = "manual"
    end

    def create
      @article = current_tenant.knowledge_articles.build(article_params)
      @article.author = current_user

      if @article.save
        redirect_to admin_knowledge_articles_path, notice: "記事を作成しました。"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @article.update(article_params)
        redirect_to admin_knowledge_articles_path, notice: "記事を更新しました。"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @article.destroy
      redirect_to admin_knowledge_articles_path, notice: "記事を削除しました。"
    end

    def publish
      @article.publish!
      redirect_to admin_knowledge_articles_path, notice: "記事を公開しました。"
    end

    def unpublish
      @article.unpublish!
      redirect_to admin_knowledge_articles_path, notice: "記事を非公開にしました。"
    end

    private

    def set_article
      @article = current_tenant.knowledge_articles.find(params[:id])
    end

    def article_params
      params.require(:knowledge_article).permit(
        :title, :slug, :content, :category, :tags, :published, :position,
        attachments: []
      )
    end
  end
end

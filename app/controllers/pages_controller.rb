class PagesController < ApplicationController
  def announcements
  end

  def revenue
  end

  def dispatch_board
    render :dispatch
  end

  def fleet
  end

  def hr
  end

  def knowledge
  end

  def workflow
    redirect_to workflow_requests_path
  end

  def faq
  end

  def admin
  end
end

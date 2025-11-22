Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }
  root "dashboard#index"

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "dashboard", to: "dashboard#index"

  scope controller: :pages do
    get "announcements"
    get "revenue"
    get "dispatch", to: "pages#dispatch_board"
    get "fleet"
    get "hr"
    get "knowledge"
    get "workflow"
    get "faq"
    get "admin"
  end

  get "/imports", to: redirect("/admin/imports/new")

  resources :workflow_requests, path: "workflows", only: [:index, :new, :create, :show]
  resources :journal_entries, only: [:index]
  resources :vehicles, only: [:index, :show, :update] do
    collection do
      get :schedule
      get :timeline_demo
    end
    scope module: :vehicles do
      resources :photos, only: [:create, :destroy]
      resources :fault_logs, only: [:create]
      resources :inspection_records, only: [:create]
    end
  end
  get "maintenance_schedule", to: "vehicles#schedule"
  resources :maintenance_events, only: [:create, :update, :destroy]
  resources :maintenance_categories
  resources :vehicle_financials, only: [:index, :show]

  namespace :admin do
    root to: "dashboard#index"
    resources :imports, only: [:new, :create]
    resources :payrolls, only: [:index] do
      delete :destroy, on: :collection
    end
    resources :employees do
      get :payroll, on: :member
      get :history, on: :member
    end
    resources :departments, only: [:index, :create, :edit, :update, :destroy]
    resources :job_categories, only: [:index, :create, :edit, :update, :destroy]
    resources :job_positions, only: [:index, :create, :edit, :update, :destroy]
    resources :grade_levels, only: [:index, :create, :edit, :update, :destroy]
    resources :evaluation_grades, only: [:index, :create, :edit, :update, :destroy]
    resources :evaluation_cycles, only: [:index, :create, :edit, :update, :destroy]
    resources :workflow_requests, only: [:index, :show] do
      post :decide, on: :member
      post :comment, on: :member
    end
    resources :users, only: [:index, :new, :create, :edit, :update]
    resources :workflow_categories do
      resources :workflow_stage_templates, only: [:create, :update, :destroy]
      resources :workflow_category_notifications, only: [:create, :destroy]
    end
    resources :metric_categories do
      resources :metric_category_items, except: [:index, :show]
    end
    resources :metric_label_mappings, only: [:index, :create]
  end
end

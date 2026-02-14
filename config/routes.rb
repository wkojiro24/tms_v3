Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }
  root "dashboard#index"

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "dashboard", to: "dashboard#index"

  resources :announcements, only: [:index, :show]
  resources :bookmarks, only: [:index, :new, :create, :edit, :update, :destroy]
  resources :knowledge_articles, only: [:index, :show], path: "knowledge"

  scope controller: :pages do
    get "revenue"
    get "dispatch", to: "dispatch_plans#index"
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
  resources :profit_loss, only: [:index] do
    collection do
      get :drilldown
      get :dashboard
      get :department_analysis
    end
  end
  resources :vehicles, only: [:index, :show, :update] do
    member do
      patch :update_fault_status
    end
    collection do
      get :schedule
      get :timeline_demo
    end
    scope module: :vehicles do
      resources :photos, only: [:create, :destroy]
      resources :fault_logs, only: [:create]
      resources :inspection_records, only: [:create]
      resources :maintenance_events, except: [:index, :show]
    end
  end
  get "maintenance_schedule", to: "vehicles#schedule"
  resources :maintenance_events, only: [:create, :update, :destroy]
  resources :maintenance_categories
  resources :orders do
    collection do
      get :recent
    end
    member do
      post :reorder
    end
  end
  resources :transport_orders do
    collection do
      post :batch_update
    end
  end
  # 稼働カレンダー
  get "availability_calendar", to: "availability_calendar#index"
  post "availability_calendar/update_driver", to: "availability_calendar#update_driver"
  post "availability_calendar/update_vehicle", to: "availability_calendar#update_vehicle"
  post "availability_calendar/batch_update", to: "availability_calendar#batch_update"

  resources :dispatch_plans, only: [:index, :show, :update] do
    collection do
      post :batch_update
      post :create_assignment
      delete :destroy_assignment
      post :confirm
      post :unlock
      post :save_vehicle_memo
      post :generate_share_token
      post :update_default_driver
    end
  end
  get "dispatch/share/:token", to: "dispatch_plans#shared", as: :dispatch_share
  resources :vehicle_financials, only: [:index, :show]
  resources :fare_negotiations, only: [:index] do
    collection do
      post :update_external_data
    end
  end
  get "cost_analysis", to: "cost_analysis#index"
  namespace :admin do
    resource :summary_setting, only: [:edit, :update, :show]
  end

  namespace :admin do
    root to: "dashboard#index"
    resources :imports, only: [:new, :create] do
      collection do
        get :template
        get :histories
      end
    end
    resources :payrolls, only: [:index] do
      delete :destroy, on: :collection
    end
    resources :payroll_items, only: [:index, :update] do
      member do
        post :toggle_hidden
      end
      collection do
        post :update_groups
        post :reorder
      end
    end
    resources :salary_scenarios do
      member do
        post :calculate
      end
      collection do
        get :driver_comparison
        post :driver_comparison_calculate
        get :driver_comparison_detail
        post :driver_comparison_detail_calculate
        post :save_draft
        delete :delete_draft
        get :draft_overview
      end
    end
    resources :employees do
      get :payroll, on: :member
      get :history, on: :member
    end
    resources :departments, only: [:index, :show, :create, :edit, :update, :destroy]
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
    resources :attendances, only: [:index, :show] do
      collection do
        get :import
        post :execute_import
        post :bulk_import
      end
    end
    resources :payroll_simulations, only: [:index, :show, :edit, :update] do
      collection do
        post :calculate
        post :bulk_approve
        post :bulk_sync_settings
        get :export
        get :grade_tables
        get :new_grade_table
        post :create_grade_table
        get :salary_settings
        get :new_salary_setting
        post :create_salary_setting
        get :missing_settings
        post :auto_create_settings
        get :salary_list
      end
      member do
        post :approve
        post :unapprove
        get :edit_grade_table
        patch :update_grade_table
        get :edit_salary_setting
        patch :update_salary_setting
      end
    end
    resources :vehicle_groups do
      collection do
        post :auto_generate
        get :suspicious_duplicates
        post :merge_suspicious
        post :ignore_suspicious
        get :data_audit
      end
    end
    resources :announcements
    resources :bookmarks
    resources :knowledge_articles, path: "knowledge" do
      member do
        post :publish
        post :unpublish
      end
    end
  end
end

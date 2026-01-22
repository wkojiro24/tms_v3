FactoryBot.define do
  factory :external_economic_datum do
    data_type { "MyString" }
    year { 1 }
    month { 1 }
    value { "9.99" }
    source { "MyString" }
    notes { "MyText" }
  end
end

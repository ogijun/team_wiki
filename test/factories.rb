# 共通ファクトリ（factory_bot）。新規テストはこれを使い、既存テストは触るときに移行する。
FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "ユーザー#{n}" }
    provider { "discord" }
    sequence(:uid) { |n| "discord-uid-#{n}" }

    trait :admin do
      role { "admin" }
    end
  end

  factory :article do
    sequence(:title) { |n| "記事タイトル#{n}" }
    association :created_by, factory: :user
  end

  factory :material do
    sequence(:title) { |n| "資料タイトル#{n}" }
    user
    sequence(:url) { |n| "https://example.com/materials/#{n}" } # 既定はリンク資料

    # file XOR url の検証があるため、ファイル系 trait は url を打ち消す
    trait :with_audio do
      url { nil }
      after(:build) do |material|
        material.file.attach(io: StringIO.new("x"), filename: "audio.mp3", content_type: "audio/mpeg")
      end
    end

    trait :with_pdf do
      url { nil }
      after(:build) do |material|
        material.file.attach(io: StringIO.new("%PDF-1.4"), filename: "doc.pdf", content_type: "application/pdf")
      end
    end

    trait :with_image do
      url { nil }
      after(:build) do |material|
        material.file.attach(io: StringIO.new("x"), filename: "img.png", content_type: "image/png")
      end
    end
  end

  factory :transcription do
    association :material, factory: [ :material, :with_audio ]
    association :author, factory: :user
    body { "文字起こし本文" }
    status { "drafting" }
  end

  factory :comment do
    association :commentable, factory: :article
    association :author, factory: :user
    body { "コメント本文" }
  end
end

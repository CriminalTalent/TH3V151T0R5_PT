module CatSize
  STAGES = ["새끼", "흉내내는 새끼", "따라 걷는 것", "방문을 배운 것", "자리를 잡은 것"].freeze

  SIZE_TABLE = {
    "새끼"          => { length: 25, weight: 1.2,  label: "손바닥에 올라오는 크기" },
    "흉내내는 새끼"  => { length: 38, weight: 2.6,  label: "무릎에 닿는 크기" },
    "따라 걷는 것"   => { length: 55, weight: 5.4,  label: "허리께까지 오는 크기" },
    "방문을 배운 것" => { length: 78, weight: 9.8,  label: "눈높이가 맞는 크기" },
    "자리를 잡은 것" => { length: 95, weight: 14.0, label: "고개를 들어야 눈이 마주치는 크기" }
  }.freeze

  ROLE_LABELS = {
    affection:  "치료",
    aggression: "공격",
    stability:  "방어",
    weirdness:  "행운",
    unknown:    "내구"
  }.freeze

  def stage_index(stage)
    idx = STAGES.index(stage.to_s)
    idx ? idx : 0
  end

  def size_of(stage)
    SIZE_TABLE[stage.to_s] || SIZE_TABLE[STAGES[0]]
  end

  def size_text(stage)
    s = size_of(stage)
    "#{s[:length]}cm / #{s[:weight]}kg (#{s[:label]})"
  end

  module_function :stage_index, :size_of, :size_text
end

module ResultJudge
  # 성공률 = 50 + 관련스탯1×2 + 관련스탯2×2 + 행운×1 - 난이도
  # 최소 20%, 최대 90%
  def success_rate(s1:, s2:, luck:, difficulty:)
    rate = 50 + (s1.to_i * 2) + (s2.to_i * 2) + luck.to_i - difficulty.to_i
    [[rate, 20].max, 90].min
  end

  def judge(rate)
    roll = rand(1..100)

    result = if roll <= 5
               :great_failure
             elsif roll > rate
               :failure
             elsif roll <= [10, (rate * 0.15).ceil].max
               :great_success
             else
               :success
             end

    [result, roll]
  end

  def result_label(result)
    {
      great_success: "대성공",
      success:       "성공",
      failure:       "실패",
      great_failure: "대실패"
    }[result]
  end
end

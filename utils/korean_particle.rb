module KoreanParticle
  def particle(word, pair)
    return pair.split("/").first if word.nil? || word.empty?

    last_char = word[-1]
    code = last_char.ord

    # 한글 음절 범위가 아니면 받침 없는 것으로 처리
    return pair.split("/").last unless code.between?(0xAC00, 0xD7A3)

    has_batchim = ((code - 0xAC00) % 28) != 0
    first, second = pair.split("/")

    has_batchim ? first : second
  end

  def eun_neun(word)
    particle(word, "은/는")
  end

  def i_ga(word)
    particle(word, "이/가")
  end

  def eul_reul(word)
    particle(word, "을/를")
  end

  def gwa_wa(word)
    particle(word, "과/와")
  end

  def euro_ro(word)
    return "로" if word.nil? || word.empty?

    last_char = word[-1]
    code = last_char.ord
    return "로" unless code.between?(0xAC00, 0xD7A3)

    jong = (code - 0xAC00) % 28

    # 받침 없음 or ㄹ 받침이면 '로'
    jong == 0 || jong == 8 ? "로" : "으로"
  end

  def with_particles(template, cat_name)
    template
      .gsub("%{cat}", cat_name)
      .gsub("%{은는}", eun_neun(cat_name))
      .gsub("%{이가}", i_ga(cat_name))
      .gsub("%{을를}", eul_reul(cat_name))
      .gsub("%{과와}", gwa_wa(cat_name))
      .gsub("%{으로로}", euro_ro(cat_name))
  end
end

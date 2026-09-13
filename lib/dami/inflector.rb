# frozen_string_literal: true
module Dami
  module Inflector
    # Caches for performance
    @plural_cache = {}
    @singular_cache = {}

    UNCOUNTABLE = %w(
      equipment information rice money species series fish sheep jeans police deer news homework
      air water sugar tea coffee milk butter cheese bread jam chocolate wine beer music art
      software love happiness furniture luggage advice work traffic weather accommodation
      education knowledge research progress health safety violence peace chaos math physics
      chemistry biology moose swine bison aircraft spacecraft salmon trout offspring
    ).freeze

    # These singular words end in 's' but are NOT plural!
    SINGULAR_ENDING_IN_S = %w(
      bus gas lens glass class mass grass brass canvas atlas bias cosmos dais iris oasis pancreas
      alias status thesis basis crisis analysis diagnosis emphasis hypothesis neurosis osmosis
      paralysis parenthesis synopsis
    ).freeze

    IRREGULAR = {
      'person' => 'people', 'man' => 'men', 'woman' => 'women', 'child' => 'children',
      'tooth' => 'teeth', 'foot' => 'feet', 'mouse' => 'mice', 'goose' => 'geese',
      'ox' => 'oxen', 'quiz' => 'quizzes', 'matrix' => 'matrices', 'vertex' => 'vertices',
      'index' => 'indices', 'sex' => 'sexes', 'move' => 'moves', 'zombie' => 'zombies',
      'cactus' => 'cacti', 'focus' => 'foci', 'fungus' => 'fungi', 'nucleus' => 'nuclei',
      'radius' => 'radii', 'stimulus' => 'stimuli', 'axis' => 'axes', 'analysis' => 'analyses',
      'basis' => 'bases', 'crisis' => 'crises', 'diagnosis' => 'diagnoses',
      'ellipsis' => 'ellipses', 'hypothesis' => 'hypotheses', 'oasis' => 'oases',
      'paralysis' => 'paralyses', 'parenthesis' => 'parentheses', 'synopsis' => 'synopses',
      'thesis' => 'theses', 'phenomenon' => 'phenomena', 'criterion' => 'criteria',
      'datum' => 'data',
      # common -s words, listed as irregular so they are handled explicitly
      'bus' => 'buses', 'gas' => 'gases', 'lens' => 'lenses', 'glass' => 'glasses',
      'class' => 'classes', 'mass' => 'masses', 'grass' => 'grasses', 'brass' => 'brasses',
      'canvas' => 'canvases', 'atlas' => 'atlases', 'bias' => 'biases', 'cosmos' => 'cosmoses',
      'dais' => 'daises', 'iris' => 'irises', 'pancreas' => 'pancreases',
      'alias' => 'aliases', 'status' => 'statuses'
    }.freeze

    IRREGULAR_REVERSE = IRREGULAR.invert.freeze

    # Rules ordered from most specific to least specific
    PLURAL_RULES = [
      # Irregular patterns
      [/^(ox)$/i, '\1en'],
      [/^(m|l)ouse$/i, '\1ice'],
      [/(quiz)$/i, '\1zes'],
      
      # Words ending in s, ss, x, z, ch, sh
      [/(ss)$/i, '\1es'],
      [/(x|z|ch|sh)$/i, '\1es'],
      
      # Words ending in o
      [/(tomat|potat|ech|her|vet)o$/i, '\1oes'],
      [/o$/i, 'os'],
      
      # Words ending in f or fe
      [/(lea|loa|thie|shel|wol|hal|cal|kni)f$/i, '\1ves'],
      [/(wi|li)fe$/i, '\1ves'],
      
      # Words ending in y
      [/([^aeiou])y$/i, '\1ies'],
      [/([aeiou]y)$/i, '\1s'],
      
      # Words ending in is
      [/(ax|test)is$/i, '\1es'],
      [/sis$/i, 'ses'],
      
      # Words ending in us
      [/(octop|vir|radi|nucle|fung|cact|stimul)us$/i, '\1i'],
      [/us$/i, 'uses'],
      
      # Words ending in um
      [/([ti])um$/i, '\1a'],
      
      # Words ending in ix or ex
      [/(matr|vert|ind)(ix|ex)$/i, '\1ices'],
      
      # Single 's' at the end (but not ss)
      [/([^s])s$/i, '\1ses'],
      
      # Default: just add s
      [/$/, 's']
    ].freeze

    SINGULAR_RULES = [
      # Irregular patterns first
      [/^oxen$/i, 'ox'],
      [/^(m|l)ice$/i, '\1ouse'],
      [/(quiz)zes$/i, '\1'],
      
      # Words ending in sses
      [/(ss)es$/i, '\1'],
      
      # Words ending in xes, zes, ches, shes
      [/(x|z|ch|sh)es$/i, '\1'],
      
      # Words ending in oes
      [/(tomat|potat|ech|her|vet)oes$/i, '\1o'],
      [/oes$/i, 'o'],
      
      # Words ending in ves
      [/(lea|loa|thie|shel|wol|hal|cal|kni)ves$/i, '\1f'],
      [/(wi|li)ves$/i, '\1fe'],
      
      # Words ending in ies
      [/([^aeiou])ies$/i, '\1y'],
      
      # Words ending in uses (from -us)
      [/([^aeiouy]|qu)uses$/i, '\1us'],
      
      # Words ending in i (Latin plurals)
      [/(octop|vir|radi|nucle|fung|cact|stimul)i$/i, '\1us'],
      
      # Words ending in a (Greek/Latin plurals)
      [/([ti])a$/i, '\1um'],
      
      # Words ending in ices
      [/(matr|vert|ind)ices$/i, '\1ex'],
      
      # Words ending in es
      [/(ax|test)es$/i, '\1is'],
      [/ses$/i, 'sis'],
      
      # Words ending in s (default - MUST be last)
      [/s$/i, '']
    ].freeze

    def self.apply_case(original, new_word)
      return new_word if original == new_word
      
      if original == original.upcase
        new_word.upcase
      elsif original == original.capitalize
        new_word.capitalize
      elsif original[0] == original[0].upcase
        new_word[0].upcase + new_word[1..-1]
      else
        new_word
      end
    end

    def self.pluralize(word)
      str = word.to_s.strip
      return str if str.empty?
      return @plural_cache[str] if @plural_cache.key?(str)

      lower = str.downcase
      
      # Uncountable
      if UNCOUNTABLE.include?(lower)
        return @plural_cache[str] = str
      end
      
      # Irregular singular -> plural (includes bus, gas, lens, etc.)
      if irregular = IRREGULAR[lower]
        return @plural_cache[str] = apply_case(str, irregular)
      end
      
      # Already irregular plural
      if IRREGULAR_REVERSE.key?(lower)
        return @plural_cache[str] = str
      end
      
      # Already plural check - a simple heuristic
      # If it ends in 's' but isn't in our singular list, it might be plural
      if lower.end_with?('s') && !lower.end_with?('ss') && !SINGULAR_ENDING_IN_S.include?(lower)
        # Try to singularize and re-pluralize to check
        test_singular = apply_singular_rules(str)
        if test_singular != str
          test_plural = apply_plural_rules(test_singular)
          if test_plural.downcase == lower
            return @plural_cache[str] = str  # Already plural
          end
        end
      end
      
      # Apply plural rules
      result = apply_plural_rules(str)
      @plural_cache[str] = result
    end

    def self.singularize(word)
      str = word.to_s.strip
      return str if str.empty?
      return @singular_cache[str] if @singular_cache.key?(str)

      lower = str.downcase
      
      # Uncountable
      if UNCOUNTABLE.include?(lower)
        return @singular_cache[str] = str
      end
      
      # Irregular plural -> singular (includes buses, gases, lenses, etc.)
      if irregular = IRREGULAR_REVERSE[lower]
        return @singular_cache[str] = apply_case(str, irregular)
      end
      
      # Already irregular singular
      if IRREGULAR.key?(lower)
        return @singular_cache[str] = str
      end
      
      # Check if it's a known singular word ending in 's'
      if SINGULAR_ENDING_IN_S.include?(lower)
        return @singular_cache[str] = str
      end
      
      # Already singular check - if it doesn't end in 's', it's probably singular
      if !lower.end_with?('s')
        return @singular_cache[str] = str
      end
      
      # Apply singular rules
      result = apply_singular_rules(str)
      @singular_cache[str] = result
    end

    private

    def self.apply_plural_rules(str)
      PLURAL_RULES.each do |regex, replacement|
        if str =~ regex
          result = str.sub(regex, replacement)
          return apply_case(str, result)
        end
      end
      str
    end

    def self.apply_singular_rules(str)
      SINGULAR_RULES.each do |regex, replacement|
        if str =~ regex
          result = str.sub(regex, replacement)
          return apply_case(str, result)
        end
      end
      str
    end
  end
end
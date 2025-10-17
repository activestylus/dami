# frozen_string_literal: true
require_relative 'test_helper'
require_relative '../lib/dami/inflector'

class InflectorTest < Minitest::Test
  # --- Pluralization Tests ---
  
  def test_pluralize_regular_nouns
    assert_equal 'posts', Dami::Inflector.pluralize('post')
    assert_equal 'users', Dami::Inflector.pluralize('user')
    assert_equal 'buses', Dami::Inflector.pluralize('bus')
    assert_equal 'aliases', Dami::Inflector.pluralize('alias')
    assert_equal 'boxes', Dami::Inflector.pluralize('box')
    assert_equal 'dishes', Dami::Inflector.pluralize('dish')
  end

  def test_pluralize_irregular_nouns
    assert_equal 'people', Dami::Inflector.pluralize('person')
    assert_equal 'children', Dami::Inflector.pluralize('child')
    assert_equal 'quizzes', Dami::Inflector.pluralize('quiz')
    assert_equal 'matrices', Dami::Inflector.pluralize('matrix')
    assert_equal 'men', Dami::Inflector.pluralize('man')
    assert_equal 'women', Dami::Inflector.pluralize('woman')
    assert_equal 'teeth', Dami::Inflector.pluralize('tooth')
    assert_equal 'feet', Dami::Inflector.pluralize('foot')
  end

  def test_pluralize_uncountable_nouns
    assert_equal 'fish', Dami::Inflector.pluralize('fish')
    assert_equal 'series', Dami::Inflector.pluralize('series')
    assert_equal 'equipment', Dami::Inflector.pluralize('equipment')
    assert_equal 'information', Dami::Inflector.pluralize('information')
    assert_equal 'money', Dami::Inflector.pluralize('money')
  end

  def test_pluralize_words_ending_in_y
    assert_equal 'categories', Dami::Inflector.pluralize('category')
    assert_equal 'stories', Dami::Inflector.pluralize('story')
    assert_equal 'ladies', Dami::Inflector.pluralize('lady')
    assert_equal 'boys', Dami::Inflector.pluralize('boy')  # vowel + y
    assert_equal 'days', Dami::Inflector.pluralize('day')  # vowel + y
  end

  def test_pluralize_words_ending_in_o
    assert_equal 'tomatoes', Dami::Inflector.pluralize('tomato')
    assert_equal 'potatoes', Dami::Inflector.pluralize('potato')
    assert_equal 'heroes', Dami::Inflector.pluralize('hero')
    assert_equal 'photos', Dami::Inflector.pluralize('photo')
    assert_equal 'pianos', Dami::Inflector.pluralize('piano')
  end

  def test_pluralize_words_ending_in_f
    assert_equal 'leaves', Dami::Inflector.pluralize('leaf')
    assert_equal 'loaves', Dami::Inflector.pluralize('loaf')
    assert_equal 'thieves', Dami::Inflector.pluralize('thief')
    assert_equal 'shelves', Dami::Inflector.pluralize('shelf')
    assert_equal 'wolves', Dami::Inflector.pluralize('wolf')
  end

  def test_pluralize_words_ending_in_us
    assert_equal 'cacti', Dami::Inflector.pluralize('cactus')
    assert_equal 'foci', Dami::Inflector.pluralize('focus')
    assert_equal 'fungi', Dami::Inflector.pluralize('fungus')
    assert_equal 'nuclei', Dami::Inflector.pluralize('nucleus')
    assert_equal 'statuses', Dami::Inflector.pluralize('status')
  end

  def test_pluralize_words_ending_in_sis
    assert_equal 'analyses', Dami::Inflector.pluralize('analysis')
    assert_equal 'bases', Dami::Inflector.pluralize('basis')
    assert_equal 'crises', Dami::Inflector.pluralize('crisis')
    assert_equal 'diagnoses', Dami::Inflector.pluralize('diagnosis')
  end

  def test_pluralize_is_idempotent
    assert_equal 'posts', Dami::Inflector.pluralize('posts')
    assert_equal 'people', Dami::Inflector.pluralize('people')
    assert_equal 'series', Dami::Inflector.pluralize('series')
    assert_equal 'buses', Dami::Inflector.pluralize('buses')
    assert_equal 'categories', Dami::Inflector.pluralize('categories')
    assert_equal 'oxen', Dami::Inflector.pluralize('oxen')
  end

  # --- Singularization Tests ---
  
  def test_singularize_regular_nouns
    assert_equal 'post', Dami::Inflector.singularize('posts')
    assert_equal 'user', Dami::Inflector.singularize('users')
    assert_equal 'bus', Dami::Inflector.singularize('buses')
    assert_equal 'alias', Dami::Inflector.singularize('aliases')
    assert_equal 'box', Dami::Inflector.singularize('boxes')
    assert_equal 'dish', Dami::Inflector.singularize('dishes')
  end

  def test_singularize_irregular_nouns
    assert_equal 'person', Dami::Inflector.singularize('people')
    assert_equal 'child', Dami::Inflector.singularize('children')
    assert_equal 'quiz', Dami::Inflector.singularize('quizzes')
    assert_equal 'matrix', Dami::Inflector.singularize('matrices')
    assert_equal 'man', Dami::Inflector.singularize('men')
    assert_equal 'woman', Dami::Inflector.singularize('women')
    assert_equal 'tooth', Dami::Inflector.singularize('teeth')
    assert_equal 'foot', Dami::Inflector.singularize('feet')
  end

  def test_singularize_uncountable_nouns
    assert_equal 'fish', Dami::Inflector.singularize('fish')
    assert_equal 'series', Dami::Inflector.singularize('series')
    assert_equal 'equipment', Dami::Inflector.singularize('equipment')
    assert_equal 'information', Dami::Inflector.singularize('information')
  end

  def test_singularize_words_ending_in_ies
    assert_equal 'category', Dami::Inflector.singularize('categories')
    assert_equal 'story', Dami::Inflector.singularize('stories')
    assert_equal 'lady', Dami::Inflector.singularize('ladies')
  end

  def test_singularize_words_ending_in_oes
    assert_equal 'tomato', Dami::Inflector.singularize('tomatoes')
    assert_equal 'potato', Dami::Inflector.singularize('potatoes')
    assert_equal 'hero', Dami::Inflector.singularize('heroes')
  end

  def test_singularize_words_ending_in_ves
    assert_equal 'leaf', Dami::Inflector.singularize('leaves')
    assert_equal 'loaf', Dami::Inflector.singularize('loaves')
    assert_equal 'thief', Dami::Inflector.singularize('thieves')
    assert_equal 'shelf', Dami::Inflector.singularize('shelves')
    assert_equal 'wolf', Dami::Inflector.singularize('wolves')
  end

  def test_singularize_words_ending_in_i
    assert_equal 'cactus', Dami::Inflector.singularize('cacti')
    assert_equal 'focus', Dami::Inflector.singularize('foci')
    assert_equal 'fungus', Dami::Inflector.singularize('fungi')
    assert_equal 'nucleus', Dami::Inflector.singularize('nuclei')
  end

  def test_singularize_words_ending_in_ses
    assert_equal 'analysis', Dami::Inflector.singularize('analyses')
    assert_equal 'basis', Dami::Inflector.singularize('bases')
    assert_equal 'crisis', Dami::Inflector.singularize('crises')
    assert_equal 'diagnosis', Dami::Inflector.singularize('diagnoses')
  end

  def test_singularize_is_idempotent
    assert_equal 'post', Dami::Inflector.singularize('post')
    assert_equal 'person', Dami::Inflector.singularize('person')
    assert_equal 'bus', Dami::Inflector.singularize('bus')
    assert_equal 'category', Dami::Inflector.singularize('category')
    assert_equal 'ox', Dami::Inflector.singularize('ox')
  end

  # --- Round-trip Tests ---
  
  def test_round_trip_pluralize_then_singularize
    words = %w[post user bus category story leaf hero analysis person child]
    words.each do |word|
      plural = Dami::Inflector.pluralize(word)
      singular = Dami::Inflector.singularize(plural)
      assert_equal word, singular, "Round-trip failed for '#{word}': #{word} -> #{plural} -> #{singular}"
    end
  end

  def test_round_trip_singularize_then_pluralize
    words = %w[posts users buses categories stories leaves heroes analyses people children]
    words.each do |word|
      singular = Dami::Inflector.singularize(word)
      plural = Dami::Inflector.pluralize(singular)
      assert_equal word, plural, "Round-trip failed for '#{word}': #{word} -> #{singular} -> #{plural}"
    end
  end

  # --- Case Preservation Tests ---
  
  def test_preserves_capitalization
    assert_equal 'Posts', Dami::Inflector.pluralize('Post')
    assert_equal 'POSTS', Dami::Inflector.pluralize('POST')
    assert_equal 'People', Dami::Inflector.pluralize('Person')
    
    assert_equal 'Post', Dami::Inflector.singularize('Posts')
    assert_equal 'POST', Dami::Inflector.singularize('POSTS')
    assert_equal 'Person', Dami::Inflector.singularize('People')
  end

  # --- Edge Cases ---
  
  def test_handles_empty_strings
    assert_equal '', Dami::Inflector.pluralize('')
    assert_equal '', Dami::Inflector.singularize('')
  end

  def test_handles_whitespace
    assert_equal 'posts', Dami::Inflector.pluralize('  post  ')
    assert_equal 'post', Dami::Inflector.singularize('  posts  ')
  end

  def test_common_orm_table_names
    # These are common in Rails/ORMs and were causing your issue
    assert_equal 'posts', Dami::Inflector.pluralize('post')
    assert_equal 'post', Dami::Inflector.singularize('posts')
    assert_equal 'posts', Dami::Inflector.pluralize('posts')  # idempotent!
    
    assert_equal 'tags', Dami::Inflector.pluralize('tag')
    assert_equal 'tag', Dami::Inflector.singularize('tags')
    assert_equal 'tags', Dami::Inflector.pluralize('tags')  # idempotent!
  end
end
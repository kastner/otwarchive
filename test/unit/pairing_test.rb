require File.dirname(__FILE__) + '/../test_helper'

class PairingTest < ActiveSupport::TestCase

  context "a pairing Tag" do
    should "have a display name" do
      assert_equal ArchiveConfig.PAIRING_CATEGORY_NAME, Pairing::NAME
    end
  end
    
  context "a new pairing tag" do
    setup do
      @pairing = Pairing.create(:name => "first/second")
    end
    should "have create its characters" do
      assert Character.find_by_name("first")
      assert Character.find_by_name("second")
    end
    should "not get get its characters as parents" do
      assert !@pairing.parents.include?(Character.find_by_name("first"))
    end
  end

  context "a pairing tag with a canonical character" do
    setup do
      @character1 = Character.create(:name => "alpha", :canonical => true)
      @pairing = Pairing.create(:name => "alpha/beta")
    end
    should "get get its characters as parents" do
      assert @pairing.parents.include?(@character1)
    end
  end

  context "a new threesome pairing tag" do
    setup do
      @pairing = Pairing.create(:name => "first/second/third")
    end
    should "have three characters" do
      assert_equal 3, Character.count
    end
  end

end
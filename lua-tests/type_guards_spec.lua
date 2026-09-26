describe("AsmonFinder TypeGuards", function()
  local TypeGuards

  before_each(function()
    AsmonFinder = nil
    _G.issecretvalue = nil
    dofile("AsmonFinder/Types.lua")
    dofile("AsmonFinder/TypeGuards.lua")
    TypeGuards = AsmonFinder.TypeGuards
  end)

  it("classifies primitive Lua types", function()
    assert.is_true(TypeGuards.IsString("Asmon"))
    assert.is_true(TypeGuards.IsNumber(12))
    assert.is_true(TypeGuards.IsBoolean(true))
    assert.is_true(TypeGuards.IsFunction(TypeGuards.IsString))
    assert.is_true(TypeGuards.IsRecord({ name = "Asmon" }))
    assert.is_false(TypeGuards.IsString(12))
    assert.is_false(TypeGuards.IsNumber("12"))
    assert.is_false(TypeGuards.IsRecord("table"))
    assert.is_false(TypeGuards.IsFiniteNumber(0 / 0))
  end)

  it("rejects empty, nil, and secret strings as public names", function()
    assert.is_nil(TypeGuards.AsPublicString(nil))
    assert.is_nil(TypeGuards.AsPublicString(""))
    assert.is_nil(TypeGuards.AsPublicString(12))
    assert.are.equal("Donald Trump", TypeGuards.AsPublicString("Donald Trump"))

    _G.issecretvalue = function(value)
      return value == "SECRET"
    end

    assert.is_nil(TypeGuards.AsPublicString("SECRET"))
    assert.are.equal("Public", TypeGuards.AsPublicString("Public"))
  end)

  it("treats compare failures as non-public strings", function()
    local original = TypeGuards.StringIsNotEmpty
    TypeGuards.StringIsNotEmpty = function()
      error("attempt to compare a secret string value")
    end

    local ok, isPublic = pcall(TypeGuards.IsPublicString, "Edwin VanCleef")
    TypeGuards.StringIsNotEmpty = original

    assert.is_true(ok)
    assert.is_false(isPublic)
  end)

  it("describes rejected values without exposing secret contents", function()
    _G.issecretvalue = function(value)
      return value == "SECRET"
    end

    assert.are.equal("secret type=string", TypeGuards.DescribeValue("SECRET"))
    assert.are.equal("number value=12", TypeGuards.DescribeValue(12))
    assert.are.equal("string empty", TypeGuards.DescribeValue(""))
    assert.are.equal(
      "table {namePlateUnitToken:string, unitToken:string}",
      TypeGuards.DescribeValue({
        namePlateUnitToken = "nameplate1",
        unitToken = "nameplate1",
      })
    )
  end)

  it("logs unique type-guard rejections with the incoming shape", function()
    ---@type string[]
    local messages = {}
    TypeGuards.SetPrinter(function(message)
      messages[#messages + 1] = message
    end)

    TypeGuards.ExpectPublicString("UnitNameSafe.GetUnitName", 7)
    TypeGuards.ExpectPublicString("UnitNameSafe.GetUnitName", 7)
    TypeGuards.ExpectPublicString("UnitNameSafe.GetUnitName", nil)
    TypeGuards.ExpectPublicString("UnitNameSafe.GetUnitName", "")
    TypeGuards.ExpectRecord("C_NamePlate.GetNamePlates", "plates")

    assert.are.equal(2, #messages)
    assert.are.equal(
      "[Asmon Finder Types] rejected UnitNameSafe.GetUnitName expected=public-string got=number value=7",
      messages[1]
    )
    assert.are.equal(
      "[Asmon Finder Types] rejected C_NamePlate.GetNamePlates expected=record got=string len=6",
      messages[2]
    )
  end)
end)

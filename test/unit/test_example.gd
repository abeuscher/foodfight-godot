extends GutTest
## Sample test to verify GUT framework is working correctly.

func test_gut_is_working():
	assert_true(true, "GUT framework is operational")

func test_basic_math():
	assert_eq(2 + 2, 4, "Basic addition works")

func test_array_operations():
	var arr = [1, 2, 3]
	assert_eq(arr.size(), 3, "Array size is correct")
	arr.append(4)
	assert_has(arr, 4, "Array contains appended element")

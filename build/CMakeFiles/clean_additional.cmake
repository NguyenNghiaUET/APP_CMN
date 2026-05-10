# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "")
  file(REMOVE_RECURSE
  "CMakeFiles\\appCMN_TESTING_autogen.dir\\AutogenUsed.txt"
  "CMakeFiles\\appCMN_TESTING_autogen.dir\\ParseCache.txt"
  "QXlsx\\CMakeFiles\\QXlsx_autogen.dir\\AutogenUsed.txt"
  "QXlsx\\CMakeFiles\\QXlsx_autogen.dir\\ParseCache.txt"
  "QXlsx\\QXlsx_autogen"
  "appCMN_TESTING_autogen"
  )
endif()

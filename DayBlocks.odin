package main

import "core:os"
import "core:time"
import "core:fmt"
import "core:strings"
import "core:text/scanner"
import "core:strconv"
import "core:thread"
import "core:intrinsics"

/*
Note this thing is really badly designed. It's storing data in the same format that's shown to the user (when calling "print"). 
Not sure why I thought this was a good idea but now I can't be bothered to change that since it works fine the way it is. It's just taking up much more space than necessary and it's a bit inconvenient to edit manually.
*/


verb_t :: enum {PRINT_TABLE, SHOW, START_TIMING, END_TIMING, HELP, QUIT, INVALID}
noun_t :: enum {
  NONE, INVALID,
  TODAY, YESTERDAY, WEEK, WORKWEEK,
  WORK, BREAK,
}
verbMap := map[string]verb_t { // NOTE: Why can't make it a constant?
  // Print
  "print" = verb_t.PRINT_TABLE,
  "p" = verb_t.PRINT_TABLE,
  "draw" = verb_t.PRINT_TABLE,
  "table" = verb_t.PRINT_TABLE,
  // Show
  "show" = verb_t.SHOW,
  "calc" = verb_t.SHOW,
  "calculate" = verb_t.SHOW,
  // Start
  "start" = verb_t.START_TIMING,
  "begin" = verb_t.START_TIMING,
  // End
  "end" = verb_t.END_TIMING,
  "e" = verb_t.END_TIMING,
  "stop" = verb_t.END_TIMING,
  // Help
  "help" = verb_t.HELP,
  "h" = verb_t.HELP,
  // Quit
  "quit" = verb_t.QUIT,
  "q" = verb_t.QUIT,
}
nounMap := map[string]noun_t { // NOTE: Why can't make it a constant?
  // Print
  "today" = noun_t.TODAY,
  "t" = noun_t.TODAY,
  "yesterday" = noun_t.YESTERDAY,
  "y" = noun_t.YESTERDAY,
  "week" = noun_t.WEEK,
  "w" = noun_t.WEEK,
  "workweek" = noun_t.WORKWEEK,
  "ww" = noun_t.WORKWEEK,
  // Start
  "work" = noun_t.WORK,
  "break" = noun_t.BREAK,
}

dataStore_t :: struct
{
  tables : [dynamic]table_t,
}
globalDataStore : dataStore_t = {}
dataStoreFilePath : string : "./DataStore.txt"
dataStoreVersionIdentifier : string : "\"Data Store 1.0\""

update_mutex := b64(false)
did_acquire :: proc(m: ^b64) -> (acquired: bool) {
	res, ok := intrinsics.atomic_compare_exchange_strong(m, false, true)
	return ok && res == false
}

main :: proc() 
{
  //
  // Setup
  //
  readOrCreateLog()


  //
  // Start a thread for updating table every minute
  //
  update_proc :: proc(t: ^thread.Thread) 
  {
    for
    {
      currentTable : ^table_t = getOrCreateCurrentTable()
      updateTable(currentTable)

      // Clear console
      fmt.printf("\e[1;1H\e[2J")
      //
      // Header
      //
      printHeader()
      //
      // Table
      //
      printTable(currentTable)

      time.sleep(61 * time.Second)
    }
  }
  if t := thread.create(update_proc); t != nil {
				t.init_context = context
				t.user_index = 0
				thread.start(t)
			}
  
  //
  // Main loop
  //
  for
  {
    currentTable : ^table_t = getOrCreateCurrentTable()

    fmt.printf("\nWhat would you like to do?\n")

    verb, noun, errorMsg := readInput()

    // CLear console
    fmt.printf("\e[1;1H\e[2J")

    // 
    // Print current time
    //
    timeNow := time.now()
    h, m, _ := time.clock_from_time(timeNow)
    fmt.printf("Current Time: %i:%i\n", h, m)

    //
    // Printing stuff
    //
    if len(errorMsg) == 0
    {
      loop_last_n_days :: proc(func: proc(^table_t)->[len(timedAction_t)]int, start_day: i64, end_day: i64 = 0)
      {
        assert(start_day >= end_day)
        accTimes : [len(timedAction_t)]int
        for index : i64 = start_day; index >= end_day; index -= 1
        {
          t := time.now()
          t._nsec -= i64(time.Hour) * 24 * index
          year, month, day := time.date(t)
          times_table := func(getTableForDate(year, month, day))
          for action in timedAction_t
          {
            accTimes[action] += times_table[action]
          }
        }
        fmt.printf("\nTotal time (%i days): %s\n", start_day-end_day + 1, getResetColorStr())
        for action in timedAction_t
        {
          fmt.printf("%s%s: %i hours, %i minutes%s\n", getActionColorStr(action), action, int(accTimes[action] / 60), accTimes[action] % 60, getResetColorStr())
        }
      }

      switch verb
      {
        case verb_t.PRINT_TABLE: 
          updateTable(currentTable)
          #partial switch(noun)
          {
            case noun_t.NONE:
              printTable(currentTable)
            case noun_t.TODAY:
              printTable(currentTable)
            case noun_t.YESTERDAY:
              loop_last_n_days(printTable, start_day=1, end_day=1)
            case noun_t.WORKWEEK:
              loop_last_n_days(printTable, start_day=i64(time.weekday(time.now()))-1)
            case noun_t.WEEK:
              loop_last_n_days(printTable, start_day=6)
            case:
              fmt.printf("Can't print table with %s (use TODAY/YESTERDAY/WEEK/WORKWEEK or just no params)\n", noun)
          }
        case verb_t.SHOW: 
          updateTable(currentTable)
          #partial switch(noun)
          {
            case noun_t.NONE:
              showTableTimes(currentTable)
            case noun_t.TODAY:
              showTableTimes(currentTable)
            case noun_t.YESTERDAY:
              loop_last_n_days(showTableTimes, start_day=1, end_day=1)
            case noun_t.WORKWEEK:
              loop_last_n_days(showTableTimes, start_day=i64(time.weekday(time.now()))-1)
            case noun_t.WEEK:
              loop_last_n_days(showTableTimes, start_day=6)
            case:
              fmt.printf("Can't print table with %s (use TODAY/YESTERDAY/WEEK/WORKWEEK or just no params)\n", noun)
          }
        case verb_t.START_TIMING: 
          startTiming(currentTable, noun)
        case verb_t.END_TIMING: 
          endTiming(currentTable)
        case verb_t.HELP: 
          printHeader()
        case verb_t.INVALID: assert(false)
        case verb_t.QUIT: 
          updateTable(currentTable)
          fmt.printf("Quitting")
          os.exit(0)
      }
    }
    else
    {
      fmt.printf("Error: %s\n", errorMsg)
    }
  }
}

printHeader :: proc()
{
  fmt.println("")
  fmt.printf("########################\n")
  fmt.printf("## Available actions: ##\n")
  fmt.printf("########################\n")

  for action in verb_t
  {
    if action == verb_t.INVALID
    {
      continue
    }

    fmt.printf("%s: ", action)
    isFirst : bool = true
    for key, keyAction in verbMap
    {
      if keyAction == action
      {
        if isFirst
        {
          fmt.printf("%s", key)
        }
        else
        {
          fmt.printf(", %s", key)
        }
        isFirst = false
      }
    }
    fmt.printf("\n")
  }

  fmt.println("")
  fmt.printf("########################\n")
  fmt.printf("## Available params:  ##\n")
  fmt.printf("########################\n")

  for noun in noun_t
  {
    if noun == noun_t.NONE
    {
      continue
    }

    fmt.printf("%s: ", noun)
    isFirst : bool = true
    for key, keyNoun in nounMap
    {
      if keyNoun == noun
      {
        if isFirst
        {
          fmt.printf("%s", key)
        }
        else
        {
          fmt.printf(", %s", key)
        }
        isFirst = false
      }
    }
    fmt.printf("\n")
  }
}

readInput :: proc() -> (resultVerb: verb_t, resultNoun: noun_t, errorMsg: string = "")
{
  data : [128]u8
  stdin := os.stdin
  read, err := os.read(stdin, data[:])

  // NOTE: Gettting error file not found and invalid handle but everything seems to be working fine...
  if(err != os.ERROR_NONE && err != os.ERROR_FILE_NOT_FOUND && err != os.ERROR_INVALID_HANDLE)
  {
    fmt.printf("Read input error Error %i\n", err) 
  }

  dataStr : string = strings.split_lines(string(data[:read]))[0]
  dataStr = strings.trim_prefix(dataStr, ":") // Allow colons as first character
  dataStr = strings.trim_right_space(dataStr)
  dataStr = strings.trim_left_space(dataStr)
  words : []string = strings.split(dataStr, " ")
  
  switch err
  {
  }

  count : int = 0
  ok : bool
  for word in words
  {
    count += 1
    if count == 1
    {
      resultVerb, ok = verbMap[word]
      if !ok
      {
        return verb_t.INVALID, noun_t.NONE, fmt.aprintf("Unknown action: %s", word)
      }
    }
    else if count == 2
    {
      resultNoun, ok = nounMap[word]
      if !ok
      {
        return resultVerb, noun_t.INVALID, fmt.aprintf("Unknown argument: %s", word)
      }
    }
    else
    {
      return verb_t.INVALID, noun_t.NONE, "Too many arguments"
    }
  }

  return resultVerb, resultNoun, errorMsg
}

// 
// Table 
// 
timedAction_t :: enum { 
  FREE, // NOTE: Keep free first to init all actions to that
  SLEEP, WORK, BREAK, 
}

table_t :: struct
{
  year : int,
  month : time.Month,
  day : int,
  rows : [24][60]timedAction_t, // 24 hours, 60 minutes

  currentAction : timedAction_t,
  actionStartTime : time.Time,
}

getOrCreateCurrentTable :: proc() -> ^table_t
{
  result : ^table_t

  numGlobalTables : int = len(globalDataStore.tables)
  if(numGlobalTables > 0)
  {
    // Only the last one could be the one we need...
    lastSavedTable : ^table_t = &globalDataStore.tables[numGlobalTables - 1]

    timeNow := time.now()
    year, month, day := time.date(timeNow)
    if(lastSavedTable.year == year && lastSavedTable.month == month && lastSavedTable.day == day)
    {
      result = lastSavedTable
    }
    else
    {
      result = createNewTable()
    }
  }
  else
  {
    result = createNewTable()
  }

  return result
}

createNewTable :: proc() -> ^table_t
{
  table : table_t = {}
  timeNow := time.now()
  table.year, table.month, table.day = time.date(timeNow)
  
  // Setup sleep hours
  for hour := 0; hour < 24; hour += 1
  {
    if hour < 7 || hour > 21
    {
      for minute := 0; minute < 60; minute += 1
      {
        table.rows[hour][minute] = timedAction_t.SLEEP
      }
    }
  }

  append(&globalDataStore.tables, table)

  result : ^table_t = &globalDataStore.tables[len(globalDataStore.tables) - 1]
  return result
}

updateTable :: proc(table : ^table_t)
{
  for !did_acquire(&update_mutex) {  }
  defer update_mutex = false

  if table.currentAction == timedAction_t.FREE
  {
    return
  }
  if table == nil
  {
    return
  }

  timeNow := time.now()
  startHour, startMin, _ := time.clock_from_time(table.actionStartTime)
  endHour, endMin, _ := time.clock_from_time(timeNow)

  fullMins : int = 0
  for h := startHour; h <= endHour; h += 1
  {
    m := 0
    countMinutesUpTo := 59
    if(h == startHour)
    {
      m = startMin
    }
    if(h == endHour)
    {
      countMinutesUpTo = endMin
    }

    for ; m <= countMinutesUpTo; m += 1
    {
      table.rows[h][m] = table.currentAction
      fullMins += 1
    }
  }

  updateDataStore()

  if fullMins > 0
  {
    fmt.printf("\n%s time %i minutes\n", table.currentAction, fullMins)
  }
}

startTiming :: proc(table : ^table_t, noun : noun_t)
{
  if(noun != noun_t.WORK && noun != noun_t.BREAK)
  {
    fmt.printf("Can't start timing with %s (use WORK or BREAK)\n", noun)
    return
  }

  if(table.currentAction == timedAction_t.SLEEP)
  {
    fmt.printf("Shouldn't be working now, hmm?\n")
  }
  else if(table.currentAction != timedAction_t.FREE)
  {
    endTiming(table) // End current one before starting a new one
  }

  table.actionStartTime = time.now()
  table.currentAction = (noun == noun_t.WORK ? timedAction_t.WORK : timedAction_t.BREAK)

  fmt.printf("\nStarted timing %s\n", table.currentAction)
}

endTiming :: proc(table : ^table_t)
{
  updateTable(table)
  fmt.printf("\nFinished timing %s\n", table.currentAction)
  table.currentAction = timedAction_t.FREE
}

getResetColorStr :: proc() -> string
{
  return "\x1B[0m"
}

getActionColorStr :: proc(action: timedAction_t) -> string
{
  result: string = ""

  switch(action)
  {
    case timedAction_t.SLEEP: result = "\x1B[34m" // Blue
    case timedAction_t.FREE: result = "\x1B[30;1m" // Gray
    case timedAction_t.WORK: result = "\x1B[31m" // Red
    case timedAction_t.BREAK: result = "\x1B[33m" // Yellow
  }

  return result
}

getTableForDate :: proc(year : int, month : time.Month, day : int) -> ^table_t
{
  for table, index in globalDataStore.tables
  {
    if(table.year == year && table.month == month && table.day == day)
    {
      return &globalDataStore.tables[index]
    }
  }

  return nil
}

printTable :: proc(table: ^table_t) -> [len(timedAction_t)]int
{
  result : [len(timedAction_t)]int

  if(table == nil)
  {
    line : string = "\n#################################################################\n"
    msg : string = fmt.aprintf("No Record")
    msg = strings.center_justify(msg, len(line) - len(msg)/2, " ")
    fmt.printf("%s\n\n%s\n\n%s", line, msg, line)

    return result
  }

  // 
  // Print Table
  //
  fmt.printf(getResetColorStr())
  printTableHeader(table)
  str_builder := strings.builder_make()
  strings.builder_grow(&str_builder, 60*24*2)  // Reserve some space for the string
  for hour := 0; hour < 24; hour += 1
  {
    fmt.sbprint(&str_builder, getResetColorStr())
    fmt.sbprintf(&str_builder, hour < 10 ? "| 0%i |" : "| %i |" , int(hour))
    for minute := 0; minute < 60; minute += 1
    {
      fmt.sbprint(&str_builder, getResetColorStr())
      if minute == 0
      {
        fmt.sbprint(&str_builder, "[")
      }
      else if minute % 10 == 0
      {
        fmt.sbprint(&str_builder, "] [")
      }

      strings.write_string(&str_builder, getActionColorStr(table.rows[hour][minute]))
      fmt.sbprint(&str_builder, "|")

      strings.write_string(&str_builder, getResetColorStr())
      if minute  == 59
      {
        fmt.sbprint(&str_builder, "]|")
      }
    }

    fmt.sbprint(&str_builder, "\n")
  }
  fmt.println(strings.to_string(str_builder))

  result = showTableTimes(table)
  return result
}

showTableTimes :: proc(table: ^table_t) -> [len(timedAction_t)]int
{
  accTime : [len(timedAction_t)]int
  if table == nil
  {
      return accTime
  }

  // 
  // Calc and Print Accumulated Time
  //
  for hour := 0; hour < 24; hour += 1
  {
    for minute := 0; minute < 60; minute += 1
    {
      action : timedAction_t = table.rows[hour][minute]
      accTime[action] += 1
    }
  }

  fmt.printf("\n")
  fmt.printf("%s\nTotal time:\n", getResetColorStr())
  for action in timedAction_t
  {
    fmt.printf("%s%s: %i hours, %i minutes\n", getActionColorStr(action), action, int(accTime[action] / 60), accTime[action] % 60)
  }
  fmt.printf(getResetColorStr())

  return accTime
}

printTableHeader :: proc(table: ^table_t)
{
  headerStr : string = "| ## |     00     |     10     |     20     |     30     |     40     |     50     |"

  table_time, ok := time.datetime_to_time(table.year, int(table.month), table.day, 0, 0, 0)
  weekday_str := ""
  if ok
  {
    weekday := time.weekday(table_time)
    switch(weekday)
    {
        case time.Weekday.Sunday: weekday_str = "Sunday"
        case time.Weekday.Monday: weekday_str = "Monday"
        case time.Weekday.Tuesday: weekday_str = "Tuesday"
        case time.Weekday.Wednesday: weekday_str = "Wednesday"
        case time.Weekday.Thursday: weekday_str = "Thursday"
        case time.Weekday.Friday: weekday_str = "Friday"
        case time.Weekday.Saturday: weekday_str = "Saturday"
    }
  }

  dateStr : string = fmt.aprintf("%i %s %i (%s)", table.day, table.month, table.year, weekday_str)
  dateStr = strings.center_justify(dateStr, len(headerStr) - len(dateStr)/2, " ") 

  fmt.printf("\n\n%s\n\n%s\n", dateStr, headerStr)
}

charToTimedAction :: proc(c : u8) -> timedAction_t
{
  result : timedAction_t
  switch(c)
  {
    case 'S': result = timedAction_t.SLEEP
    case '0': result = timedAction_t.FREE
    case 'W': result = timedAction_t.WORK
    case 'B': result = timedAction_t.BREAK 
  }

  return result
}

timedActionToChar :: proc(action : timedAction_t) -> string
{
  result : string = ""
  switch(action)
  {
    case timedAction_t.SLEEP: result = "S"
    case timedAction_t.FREE: result  = "O"
    case timedAction_t.WORK: result  = "W"
    case timedAction_t.BREAK: result = "B"
  }

  return result
}

terminateBecauseCorruptedLog :: proc()
{
  fmt.println("Log file is corrupted. Terminating.")
  os.exit(1)
}

readOrCreateLog :: proc()
{
  data, success := os.read_entire_file_from_filename(dataStoreFilePath)
  if(success)
  {
    s : scanner.Scanner
    scanner.init(&s, string(data))

    scanner.scan(&s)
    versionString := scanner.token_text(&s)
    if(strings.compare(versionString, dataStoreVersionIdentifier) != 0)
    {
      terminateBecauseCorruptedLog()
    }
    for
    {
      scanner.scan(&s)
      tableString := scanner.token_text(&s)
      if(strings.compare(tableString, "TABLE") != 0)
      {
        terminateBecauseCorruptedLog()
      }
      table : table_t = {}

      scanner.scan(&s)
      day := scanner.token_text(&s)
      scanner.scan(&s)
      month := scanner.token_text(&s)
      scanner.scan(&s)
      year := scanner.token_text(&s)
      ok : bool
      table.day, ok = strconv.parse_int(day)
      if(!ok) {terminateBecauseCorruptedLog()}
      monthAsInt : int
      monthAsInt , ok = strconv.parse_int(month)
      if(!ok) {terminateBecauseCorruptedLog()}
      table.month = time.Month(monthAsInt)
      table.year, ok = strconv.parse_int(year)
      if(!ok) {terminateBecauseCorruptedLog()}
      for hour := 0; hour < 24; hour += 1
      {
        scanner.scan(&s)
        hourString := scanner.token_text(&s)
        for minute := 0; minute < 60; minute += 1
        {
          table.rows[hour][minute] = charToTimedAction(hourString[minute])
        }
      }

      append(&globalDataStore.tables, table)
      if(scanner.peek_token(&s) == scanner.EOF)
      {
        break
      }
    }
  }
  else
  {
    fmt.println("Database file does not exist.")
  }
}

writeToFile :: proc(fileHandle : os.Handle) -> os.Errno
{
  // NOTE: tried dumping memory to a file but it works only twice then I'm getting error 1784? Something Im misunderstanding there?
  //_, err := os.write_ptr(fileHandle, &globalDataStore, size)

  err : os.Errno
  _, err = os.write_string(fileHandle, fmt.aprintf("%s\n\n", dataStoreVersionIdentifier)) // or_return NOTE: or_return is a neat thing but doesn't work with os calls...
  if(err != os.ERROR_NONE) { return err }
  for table in globalDataStore.tables
  {
    _, err = os.write_string(fileHandle, "TABLE\n")
    if(err != os.ERROR_NONE) { return err }

    _, err = os.write_string(fileHandle, fmt.aprintf("%i %i %i \n", table.day, int(table.month), table.year))
    if(err != os.ERROR_NONE) { return err }

    for hour := 0; hour < 24; hour += 1
    {
      for minute := 0; minute < 60; minute += 1
      {
        _, err = os.write_string(fileHandle, timedActionToChar(table.rows[hour][minute]))
        if(err != os.ERROR_NONE) { return err }
      }
      _, err = os.write_string(fileHandle, "\n")
      if(err != os.ERROR_NONE) { return err }
    }
    _, err = os.write_string(fileHandle, "\n")
    if(err != os.ERROR_NONE) { return err }
  }
  return err
}

updateDataStore :: proc()
{
  dataStoreTempFilePath : string = "./DataStoreTmp.txt"
  tempFileHandle, err := os.open(dataStoreTempFilePath, os.O_CREATE | os.O_RDWR)
  if(err == os.ERROR_NONE)
  {
    defer os.close(tempFileHandle)
    err = writeToFile(tempFileHandle)
    if(err != os.ERROR_NONE)
    {
      fmt.printf("Failed to write DataStoreTmp file, error %i\n", err)
      return
    }
  }
  else
  {
    fmt.printf("Failed to open DataStoreTmp.txt, error %i\n", err)
    return
  }

  //
  // Rename temp file
  // 
  {
    logFileExists := os.is_file(dataStoreFilePath)
    if(logFileExists)
    {
      err := os.remove(dataStoreFilePath)
      if(err != os.ERROR_NONE)
      {
        fmt.printf("Failed to replace existing DataStore.txt! Error: %i\n", err)
        return
      }
    }
    else
    {
      fmt.printf("DataStore.txt does not exist, creating a new one...\n")
    }
    err := os.rename(dataStoreTempFilePath, dataStoreFilePath)
    if(err != 0)
    {
      fmt.printf("Failed to rename tmp file but current DataStore.txt is removed! \nPlease rename it manually. \nError: %i\n", err)
      return
    }
    err = os.remove(dataStoreTempFilePath)
  }
}

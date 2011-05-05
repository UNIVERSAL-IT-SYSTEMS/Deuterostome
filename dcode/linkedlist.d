| -*- mode: d; -*-

/LINKEDLIST 100 {

|==================== allocators ========================

  |================ static ===============================
  | size ~default | store
  |
  | preallocate 'size' links, each link data created
  |  by 'default'
  |
  /static {
    save [
      /default 4 -1 roll
      /size 6 -1 roll
      /free null
      /_getfree {free dup _next /free name} bind
      /_setfree {free 1 index _setnext /free name} bind
    ] 1 index capsave makestruct {
      /free null size {
        [exch null default]
        dup _next dup null eq ~pop {1 index exch _setprev} ifelse
      } repeat def
    } 1 index indict
    exch restore
  } bind def
  
  |=============== dynamic =================================
  | ~default | store
  |
  | create links on demand (keeping removed elements for reuse),
  |  fill in data element for new elements by 'default'
  |
  /dynamic {
    save [
      /default 4 -1 roll
      /free null
      /_getfree {
        free null eq {[null null default]} {free dup _next /free name} ifelse
      } bind
      /_setfree {free 1 index _setnext /free name} bind
    ] 1 index capsave makestruct
    exch restore
  } bind def

  |==================== linked ==========================
  | linkedlist | store
  |
  | Share store with 'linkedlist' (originally initialized
  |  with another 'linked' or a dynamic or static).
  |
  /linked {/store get} bind def

|=================== constructor ============================

  |=========== new ======================
  | store | dict
  |
  | store is a storage allocator: linked, static or dynamic
  |   used to add and destroy links.
  |
  /new {
    [
      /store 3 -1 roll
      {/head /tail} ~null forall
      /len 0 |]
    makestruct_close
  } def

|================ funcs called in link list ===============

  |==================== data ================
  | [next prev data] | data
  |
  | get the data element of a link
  |
  /data {2 get} bind def

  |=================== setdata ==============
  | data [next prev ?] | --
  |
  | replace the data element of a link
  |
  /setdata {2 put} bind def

  |================= remove ======================
  | [next prev data] | --
  |
  | remove an allocated link, and put it on
  |  the free store.
  |
  /remove {dup _unlink _setfree} bind def

  |================== prepend ====================
  | -- | [next prev data]
  |
  | allocate a link from the store and make it
  | the head of the list
  |
  /prepend {_getfree null 1 index _insert} bind def

  |================== append ====================
  | -- | [next prev data]
  |
  | allocate a link from the store and make it
  | the tail of the list
  |
  /append {_getfree tail 1 index _insert} bind def

  |============== insert ========================
  |
  | [next prev data]/null [next prev data] | --
  |
  | move the second after the first in the same list.
  | Both are already allocated links -- we are just 
  |  reordering, without reordering the rest of the links.
  | If the first link is null, prepend the second to the list.
  |
  /insert {dup _unlink _insert} bind def

  |==================== move ========================
  | dest-linked-list [next prev data]/null [next prev data] | --
  |
  | move the second link from the current dictionary to the
  |  destination linked list, and insert after the first link 
  |  (which must belong to that list).
  | Both dictionaries must a common store allocator.
  | If the first link is null, prepend the second to the list.
  |
  /move {dup _unlink ~_insert 4 -1 roll indict} bind def

  |================== nth ======================
  | n | dict
  |
  | get the nth allocate link, counting from 0,
  | or from the tail, counting from -1.
  |
  /nth {
    dup 0 ge {
      head  1  1 4 -1 roll {pop _next} for
    } {
      tail -2 -1 4 -1 roll {pop _prev} for
    } ifelse
  } bind def

  |=============== getlength ====================
  | -- | length
  |
  | return length of the list
  |
  /getlength ~len def

  |================ iter ======================
  | ~active | bool-if-exited-early
  |
  | ~active: [next prev data] | bool
  |
  |   dict is the next list element, 
  |   bool is true iff we are to exit loop
  |
  | iterate over a list, calling ~active on
  |  each element until ~active returns true.
  | return true if any ~active returned true.
  |
  | expects linked list at top of dict stack, with
  |  LINKEDLIST directly underneath
  |
  /iter {openlist /func} {
    false head {
      exch        {pop true exit} if
      dup null eq {pop false exit} if
      /func find ~enddict ~enddict
      [ 4 index _next ~enddict push |]
    } loop
  } caplocalfunc def

|==================== internal ==========================  

  | [next prev data] | --
  /_unlink {
    dup _next null ne {
      dup _prev 1 index _next _setprev
    } {
      dup _prev /tail name
    } ifelse

    dup _prev null ne {
      dup _next exch _prev _setnext
    } {
      _next /head name
    } ifelse
    /len len 1 sub def
  } bind def

  | [next prev data]/null [next prev data] | --
  /_insert {
    2 copy _setprev                      | a1 \<-- a2

    1 index null eq {
      head 1 index _setnext              | a2 --\> head
      dup /head name                     | head == a2
    } {
      1 index _next 1 index _setnext     | a2 --\> a3
      2 copy exch _setnext               | a1 --\> a2
    } ifelse
    exch pop

    dup _next null eq {
      /tail name                         | tail == a2
    } {
      dup _next _setprev                 | a2 \<-- a3
    } ifelse
    
    /len len 1 add def
  } bind def
  
  | [next prev data] | next
  /_next {0 get} bind def

  | [next prev data] | prev
  /_prev {1 get} bind def  

  | next [? prev data] | --
  /_setnext {0 put} bind def

  | prev [next ? data] | --
  /_setprev {1 put} bind def

  |============ allocation store ==================

  | -- | [? ? ?]
  /_getfree {~_getfree store indict} bind def

  | [? ? ?] | --
  /_setfree {~_setfree store indict} bind def

} moduledef

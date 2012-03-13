
A smarter alternative to OpenStruct
===================================


Introduction
------------

If you're unhappy with `OpenStruct` (like myself), you might consider using `SmartHash` because of these major features:

* You can access attributes as methods or keys. Both `person.name` and `person[:name]` will work.
* Attribute access is strict by default. `person.invalid_stuff` will raise an exception instead of returning the stupid `nil`.
* You can use **any** attribute names. `person.size = "XL"` will work as intended.
* `SmartHash` descends from `Hash` and inherits its rich feature set.


Setup
-----

~~~
$ gem install smart_hash
~~~

Or using Bundler's `Gemfile`:

~~~
gem "smart_hash"
#gem "smart_hash", :git => "git://github.com/dadooda/smart_hash.git"     # Edge version.
~~~


Usage
-----

Create an object and set a few attributes:

~~~
>> person = SmartHash[]
>> person.name = "John"
>> person.age = 25

>> person
=> {:name=>"John", :age=>25}
~~~

Read attributes:

~~~
>> person.name
=> "John"
>> person[:name]
=> "John"
~~~

Access an unset attribute:

~~~
>> person.invalid_stuff
KeyError: key not found: :invalid_stuff
>> person[:invalid_stuff]
=> nil
~~~

Please note that `[]` access is always non-strict since `SmartHash` behaves as `Hash` here.

Manipulate attributes which exist as methods:

~~~
>> person = SmartHash[:name => "John"]
>> person.size
=> 1
>> person.size = "XL"
>> person.size
=> "XL"
~~~

**IMPORTANT:** You can use any attribute names excluding these: `default`, `default_proc`, `strict`.

Use `Hash` features, e.g. merge:

~~~
>> person = SmartHash[:name => "John"]
>> person.merge(:surname => "Smith", :age => 25)
=> {:name=>"John", :surname=>"Smith", :age=>25}
~~~

, or iterate:

~~~
>> person.each {|k, v| puts "#{k}: #{v}"}
name: John
surname: Smith
age: 25
~~~

Suppose you want to disable strict mode:

~~~
>> person = SmartHash[]
>> person.strict = false

>> person.name
=> nil
>> person.age
=> nil
~~~

`SmartHash::Loose` is non-strict upon construction:

~~~
>> person = SmartHash::Loose[]
>> person.name
=> nil
>> person.age
=> nil
~~~

Suppose you **know** you will use the `size` attribute and you don't want any interference with the `#size` method. Use attribute declaration:

~~~
>> person = SmartHash[]
>> person.declare(:size)
>> person.size
KeyError: key not found: :size
>> person.size = "XL"
>> person.size
=> "XL"
~~~

Suppose you set an attribute and want to ensure that it's not overwritten. Use attribute protection:

~~~
>> person = SmartHash[]
>> person.name = "John"
>> person.protect(:name)

>> person.name = "Bob"
ArgumentError: Attribute 'name' is protected
~~~


Compatibility
-------------

Tested to run on:

* Ruby 1.9.2-p180, Linux, RVM

Compatibility issue reports will be greatly appreciated.


Copyright
---------

Copyright &copy; 2012 Alex Fortuna.

Licensed under the MIT License.


Feedback
--------

Send bug reports, suggestions and criticisms through [project's page on GitHub](http://github.com/dadooda/smart_hash).

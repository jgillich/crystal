require 'spec_helper'

describe 'Type inference: def instance' do

  it "types a call with an int" do
    input = parse 'def foo; 1; end; foo'
    mod = infer_type input
    input.last.target_def.return.should eq(mod.int)
  end

  it "types a call with a primitive argument" do
    input = parse 'def foo(x); x; end; foo 1'
    mod = infer_type input
    input.last.target_def.return.should eq(mod.int)
  end

  it "types a call with an object type argument" do
    input = parse 'def foo(x); x; end; foo Object.new'
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0))
  end

  it "types a call returning new type" do
    input = parse 'def foo; Object.new; end; foo'
    mod = infer_type input
    input.last.target_def.return.should eq(mod.object)
  end

  test_type = "class Foo; #{rw :value}; end"

  it "types a call not returning path of argument with primitive type" do
    input = parse "#{test_type}; def foo(x); x.value; end; f = Foo.new; f.value = 1; foo(f)"
    mod = infer_type input
    input.last.target_def.return.should eq(mod.int)
  end

  it "types a call returning path of self" do
    input = parse "#{test_type}; f = Foo.new; f.value = Object.new; f.value"
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0, '@value'))
  end

  it "types a call returning path of argument" do
    input = parse "#{test_type}; def foo(x); x.value; end; f = Foo.new; f.value = Object.new; foo(f)"
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0, '@value'))
  end

  it "types a call returning path of second argument" do
    input = parse "#{test_type}; def foo(y, x); x.value; end; f = Foo.new; f.value = Object.new; foo(0, f)"
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(1, '@value'))
  end

  it "types a call returning path of self" do
    input = parse %Q(
      #{test_type}
      class Foo
        def foo
          self.value
        end
      end

      x = Foo.new
      x.value = Foo.new
      x.foo)
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0, '@value'))
  end

  it "types a call returning path of self" do
    input = parse %Q(
      #{test_type}
      class Foo
        def foo
          self.value.value
        end
      end

      x = Foo.new
      x.value = Foo.new
      x.value.value = Object.new
      x.foo)
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0, '@value', '@value'))
  end

  it "types a call returning self" do
    input = parse %Q(
      class Foo
        def foo
          self
        end
      end
      Foo.new.foo
    )

    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0))
  end

  it "types a call returning path of argument of second level call" do
    input = parse %Q(
      def foo(x)
        x
      end

      def bar(x)
        foo(x)
      end

      bar(Object.new)
    )
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0))
  end

  it "types a call to object returning path of argument" do
    input = parse %Q(
      class Foo
        def foo(x)
          x
        end
      end
      Foo.new.foo(Object.new)
    )

    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(1))
  end

  it "types a call returning path of self of second level call" do
    input = parse %Q(
      class Foo
        def foo(x)
          x
        end
      end

      def bar(x)
        Foo.new.foo(x)
      end

      bar(Object.new)
    )
    mod = infer_type input
    input.last.target_def.return.should eq(Path.new(0))
  end

  it "cache mutations on accessor" do
    input = parse %Q(
      #{test_type}
      f = Foo.new
      f.value = 1
      )

    mod = infer_type input
    mod.types['Foo'].defs['value='].lookup_instance([ObjectType.new('Foo'), mod.int]).mutations.should eq([Mutation.new(Path.new(0, '@value'), mod.int)])
  end

  it "reuses mutation" do
    assert_type(%Q(
      #{test_type}

      def foo(x)
        x.value = 1
      end

      f = Foo.new
      foo(f)

      g = Foo.new
      foo(g)
      g
      )
    ) { ObjectType.new("Foo").with_var("@value", int) }
  end
end
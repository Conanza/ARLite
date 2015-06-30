require 'activerecordlite'
require 'securerandom'

describe SQLObject do
  before(:each) { DBConnection.reset }
  after(:each) { DBConnection.reset }

  before(:each) do
    class Cat < SQLObject
      self.finalize!
    end

    class Human < SQLObject
      self.table_name = 'humans'

      self.finalize!
    end
  end

  describe '::set_table/::table_name' do
    it '::set_table_name sets table name' do
      expect(Human.table_name).to eq('humans')
    end

    it '::table_name generates default name' do
      expect(Cat.table_name).to eq('cats')
    end
  end

  describe '::columns' do
    it '::columns gets the columns from the table and symbolizes them' do
      expect(Cat.columns).to eq([:id, :name, :owner_id])
    end

    it '::columns creates getter methods for each column' do
      c = Cat.new
      expect(c.respond_to? :something).to be false
      expect(c.respond_to? :name).to be true
      expect(c.respond_to? :id).to be true
      expect(c.respond_to? :owner_id).to be true
    end

    it '::columns creates setter methods for each column' do
      c = Cat.new
      c.name = "Nick Diaz"
      c.id = 209
      c.owner_id = 2
      expect(c.name).to eq 'Nick Diaz'
      expect(c.id).to eq 209
      expect(c.owner_id).to eq 2
    end

    it '::columns created setter methods use attributes hash to store data' do
      c = Cat.new
      c.name = "Nick Diaz"
      expect(c.instance_variables).to eq [:@attributes]
      expect(c.attributes[:name]).to eq 'Nick Diaz'
    end
  end

  describe '#initialize' do
    it '#initialize properly sets values' do
      c = Cat.new(name: 'Don Frye', id: 100, owner_id: 4)
      expect(c.name).to eq 'Don Frye'
      expect(c.id).to eq 100
      expect(c.owner_id).to eq 4
    end

    it '#initialize throws the error with unknown attr' do
      expect do
        Cat.new(favorite_band: 'Anybody but The Eagles')
      end.to raise_error "unknown attribute 'favorite_band'"
    end
  end

  describe '::parse_all' do
    it '::parse_all turns an array of hashes into objects' do
      hashes = [
        { name: 'cat1', owner_id: 1 },
        { name: 'cat2', owner_id: 2 }
      ]

      cats = Cat.parse_all(hashes)
      expect(cats.length).to eq(2)
      hashes.each_index do |i|
        expect(cats[i].name).to eq(hashes[i][:name])
        expect(cats[i].owner_id).to eq(hashes[i][:owner_id])
      end
    end
  end

  describe '::all/::find' do
    it '::all returns all the cats' do
      cats = Cat.all

      expect(cats.count).to eq(5)
      cats.all? { |cat| expect(cat).to be_instance_of(Cat) }
    end

    it '::find finds objects by id' do
      c = Cat.find(1)

      expect(c).not_to be_nil
      expect(c.name).to eq('Breakfast')
    end

    it '::find returns nil if no object has the given id' do
      expect(Cat.find(123)).to be_nil
    end
  end

  describe '#insert' do
    let(:cat) { Cat.new(name: 'Gizmo', owner_id: 1) }

    before(:each) { cat.insert }

    it '#attribute_values returns array of values' do
      cat = Cat.new(id: 123, name: 'cat1', owner_id: 1)

      expect(cat.attribute_values).to eq([123, 'cat1', 1])
    end

    it '#insert inserts a new record' do
      expect(Cat.all.count).to eq(6)
    end

    it '#insert sets the id' do
      expect(cat.id).to_not be_nil
    end

    it '#insert creates record with proper values' do
      # pull the cat again
      cat2 = Cat.find(cat.id)

      expect(cat2.name).to eq('Gizmo')
      expect(cat2.owner_id).to eq(1)
    end
  end

  describe '#update' do
    it '#update changes attributes' do
      human = Human.find(2)

      human.fname = 'Matthew'
      human.lname = 'von Rubens'
      human.update

      # pull the human again
      human = Human.find(2)
      expect(human.fname).to eq('Matthew')
      expect(human.lname).to eq('von Rubens')
    end
  end

  describe '#save' do
    it '#save calls save/update as appropriate' do
      human = Human.new
      expect(human).to receive(:insert)
      human.save

      human = Human.find(1)
      expect(human).to receive(:update)
      human.save
    end
  end
end

describe 'Searchable' do
  before(:each) { DBConnection.reset }
  after(:each) { DBConnection.reset }

  before(:all) do
    class Cat < SQLObject
      finalize!
    end

    class Human < SQLObject
      self.table_name = 'humans'

      finalize!
    end
  end

  it '#where searches with single criterion' do
    cats = Cat.where(name: 'Breakfast')
    cat = cats.first

    expect(cats.length).to eq(1)
    expect(cat.name).to eq('Breakfast')
  end

  it '#where can return multiple objects' do
    humans = Human.where(house_id: 1)
    expect(humans.length).to eq(2)
  end

  it '#where searches with multiple criteria' do
    humans = Human.where(fname: 'Matt', house_id: 1)
    expect(humans.length).to eq(1)

    human = humans[0]
    expect(human.fname).to eq('Matt')
    expect(human.house_id).to eq(1)
  end

  it '#where returns [] if nothing matches the criteria' do
    expect(Human.where(fname: 'Nowhere', lname: 'Man')).to eq([])
  end
end

describe 'AssocOptions' do
  describe 'BelongsToOptions' do
    it 'provides defaults' do
      options = BelongsToOptions.new('house')

      expect(options.foreign_key).to eq(:house_id)
      expect(options.class_name).to eq('House')
      expect(options.primary_key).to eq(:id)
    end

    it 'allows overrides' do
      options = BelongsToOptions.new('owner',
                                     foreign_key: :human_id,
                                     class_name: 'Human',
                                     primary_key: :human_id
      )

      expect(options.foreign_key).to eq(:human_id)
      expect(options.class_name).to eq('Human')
      expect(options.primary_key).to eq(:human_id)
    end
  end

  describe 'HasManyOptions' do
    it 'provides defaults' do
      options = HasManyOptions.new('cats', 'Human')

      expect(options.foreign_key).to eq(:human_id)
      expect(options.class_name).to eq('Cat')
      expect(options.primary_key).to eq(:id)
    end

    it 'allows overrides' do
      options = HasManyOptions.new('cats', 'Human',
                                   foreign_key: :owner_id,
                                   class_name: 'Kitten',
                                   primary_key: :human_id
      )

      expect(options.foreign_key).to eq(:owner_id)
      expect(options.class_name).to eq('Kitten')
      expect(options.primary_key).to eq(:human_id)
    end
  end

  describe 'AssocOptions' do
    before(:all) do
      class Cat < SQLObject
        self.finalize!
      end

      class Human < SQLObject
        self.table_name = 'humans'

        self.finalize!
      end
    end

    it '#model_class returns class of associated object' do
      options = BelongsToOptions.new('human')
      expect(options.model_class).to eq(Human)

      options = HasManyOptions.new('cats', 'Human')
      expect(options.model_class).to eq(Cat)
    end

    it '#table_name returns table name of associated object' do
      options = BelongsToOptions.new('human')
      expect(options.table_name).to eq('humans')

      options = HasManyOptions.new('cats', 'Human')
      expect(options.table_name).to eq('cats')
    end
  end
end

describe 'Associatable' do
  before(:each) { DBConnection.reset }
  after(:each) { DBConnection.reset }

  before(:all) do
    class Cat < SQLObject
      belongs_to :human, foreign_key: :owner_id

      finalize!
    end

    class Human < SQLObject
      self.table_name = 'humans'

      has_many :cats, foreign_key: :owner_id
      belongs_to :house

      finalize!
    end

    class House < SQLObject
      has_many :humans

      finalize!
    end
  end

  describe '#belongs_to' do
    let(:breakfast) { Cat.find(1) }
    let(:devon) { Human.find(1) }

    it 'fetches `human` from `Cat` correctly' do
      expect(breakfast).to respond_to(:human)
      human = breakfast.human

      expect(human).to be_instance_of(Human)
      expect(human.fname).to eq('Devon')
    end

    it 'fetches `house` from `Human` correctly' do
      expect(devon).to respond_to(:house)
      house = devon.house

      expect(house).to be_instance_of(House)
      expect(house.address).to eq('26th and Guerrero')
    end

    it 'returns nil if no associated object' do
      stray_cat = Cat.find(5)
      expect(stray_cat.human).to eq(nil)
    end
  end

  describe '#has_many' do
    let(:ned) { Human.find(3) }
    let(:ned_house) { House.find(2) }

    it 'fetches `cats` from `Human`' do
      expect(ned).to respond_to(:cats)
      cats = ned.cats

      expect(cats.length).to eq(2)

      expected_cat_names = %w(Haskell Markov)
      2.times do |i|
        cat = cats[i]

        expect(cat).to be_instance_of(Cat)
        expect(cat.name).to eq(expected_cat_names[i])
      end
    end

    it 'fetches `humans` from `House`' do
      expect(ned_house).to respond_to(:humans)
      humans = ned_house.humans

      expect(humans.length).to eq(1)
      expect(humans[0]).to be_instance_of(Human)
      expect(humans[0].fname).to eq('Ned')
    end

    it 'returns an empty array if no associated items' do
      catless_human = Human.find(4)
      expect(catless_human.cats).to eq([])
    end
  end
end

describe 'Associatable' do
  before(:each) { DBConnection.reset }
  after(:each) { DBConnection.reset }

  before(:all) do
    class Cat < SQLObject
      belongs_to :human, foreign_key: :owner_id

      finalize!
    end

    class Human < SQLObject
      self.table_name = 'humans'

      has_many :cats, foreign_key: :owner_id
      belongs_to :house

      finalize!
    end

    class House < SQLObject
      has_many :humans

      finalize!
    end
  end

  describe '::assoc_options' do
    it 'defaults to empty hash' do
      class TempClass < SQLObject
      end

      expect(TempClass.assoc_options).to eq({})
    end

    it 'stores `belongs_to` options' do
      cat_assoc_options = Cat.assoc_options
      human_options = cat_assoc_options[:human]

      expect(human_options).to be_instance_of(BelongsToOptions)
      expect(human_options.foreign_key).to eq(:owner_id)
      expect(human_options.class_name).to eq('Human')
      expect(human_options.primary_key).to eq(:id)
    end

    it 'stores options separately for each class' do
      expect(Cat.assoc_options).to have_key(:human)
      expect(Human.assoc_options).to_not have_key(:human)

      expect(Human.assoc_options).to have_key(:house)
      expect(Cat.assoc_options).to_not have_key(:house)
    end
  end

  describe '#has_one_through' do
    before(:all) do
      class Cat
        has_one_through :home, :human, :house

        self.finalize!
      end
    end

    let(:cat) { Cat.find(1) }

    it 'adds getter method' do
      expect(cat).to respond_to(:home)
    end

    it 'fetches associated `home` for a `Cat`' do
      house = cat.home

      expect(house).to be_instance_of(House)
      expect(house.address).to eq('26th and Guerrero')
    end
  end
end

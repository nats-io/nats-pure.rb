# frozen_string_literal: true

RSpec.describe NATS::Utils::Config::DSL do
  subject { Class.new(NATS::Utils::Config, &block) }

  let(:option) { subject.schema[:option] }
  let(:config) { subject.configs[:option] }

  describe "#string" do
    let(:block) do
      option_params = params
      proc { string(:option, option_params) }
    end

    let(:params) do
      {
        default: "string",
        as: :name,
        in: %w[file memory]
      }
    end

    it "registers a integer option" do
      expect(option).to be_kind_of(NATS::Utils::Config::StringOption)
    end

    it "sets options attributes" do
      expect(option).to have_attributes(name: :option, params: params)
    end
  end

  describe "#integer" do
    let(:block) do
      option_params = params
      proc { integer(:option, option_params) }
    end

    let(:params) do
      {
        default: 1,
        in: (1..5),
        max: 5,
        min: 1
      }
    end

    it "registers a integer option" do
      expect(option).to be_kind_of(NATS::Utils::Config::IntegerOption)
    end

    it "sets options attributes" do
      expect(option).to have_attributes(name: :option, params: params)
    end
  end

  describe "#bool" do
    let(:block) do
      option_params = params
      proc { bool(:option, option_params) }
    end

    let(:params) { {default: true} }

    it "registers a bool option" do
      expect(option).to be_kind_of(NATS::Utils::Config::BoolOption)
    end

    it "sets options attributes" do
      expect(option).to have_attributes(name: :option, params: params)
    end
  end

  describe "#date" do
    let(:block) do
      option_params = params
      proc { date(:option, option_params) }
    end

    let(:params) { {} }

    it "registers a date option" do
      expect(option).to be_kind_of(NATS::Utils::Config::DateOption)
    end

    it "sets options attributes" do
      expect(option).to have_attributes(name: :option)
    end
  end

  describe "#time" do
    let(:block) do
      option_params = params
      proc { time(:option, option_params) }
    end

    let(:params) { {} }

    it "registers a time option" do
      expect(option).to be_kind_of(NATS::Utils::Config::TimeOption)
    end

    it "sets options attributes" do
      expect(option).to have_attributes(name: :option)
    end
  end

  describe "#io" do
    let(:block) do
      option_params = params
      proc { io(:option, option_params) }
    end

    let(:params) { {} }

    it "registers an IO option" do
      expect(option).to be_kind_of(NATS::Utils::Config::IoOption)
    end

    it "sets options attributes" do
      expect(option).to have_attributes(name: :option)
    end
  end

  describe "#hash" do
    let(:block) do
      option_params = params
      proc { hash(:option, option_params) }
    end

    let(:params) { {default: {}} }

    it "registers a hash option" do
      expect(option).to be_kind_of(NATS::Utils::Config::HashOption)
    end

    it "sets options attributes" do
      expect(option).to have_attributes(name: :option, params: params)
    end
  end

  describe "#array" do
    context "when params[:of] is of default types" do
      let(:block) do
        proc { array(:option, of: :integer, default: []) }
      end

      it "registers an array option" do
        expect(option).to be_kind_of(NATS::Utils::Config::ArrayOption)
      end

      it "sets options attributes" do
        expect(option).to have_attributes(
          name: :option,
          params: {
            default: [],
            of: :integer,
            item: be_kind_of(NATS::Utils::Config::IntegerOption)
          }
        )
      end
    end

    context "when params[:of] is a custom type" do
      let(:block) do
        proc do
          config :custom do
            integer :integer
            string :string
          end

          array :option, of: :custom
        end
      end

      it "registers an array option" do
        expect(option).to be_kind_of(NATS::Utils::Config::ArrayOption)
      end

      it "sets options attributes" do
        expect(option).to have_attributes(
          name: :option,
          params: {
            of: :custom,
            item: be_kind_of(NATS::Utils::Config::ObjectOption).and(
              have_attributes(
                name: :option,
                params: {config: subject.configs[:custom]}
              )
            )
          }
        )
      end
    end

    context "when block is given" do
      let(:block) do
        proc do
          array :option do
            integer :integer
            string :string
          end
        end
      end

      it "registers an array option" do
        expect(option).to be_kind_of(NATS::Utils::Config::ArrayOption)
      end

      it "creates a custom type" do
        expect(config).to have_attributes(
          superclass: NATS::Utils::Config,
          schema: include(
            integer: be_kind_of(NATS::Utils::Config::IntegerOption),
            string: be_kind_of(NATS::Utils::Config::StringOption)
          )
        )
      end

      it "sets options attributes" do
        expect(option).to have_attributes(
          name: :option,
          params: {
            item: be_kind_of(NATS::Utils::Config::ObjectOption).and(
              have_attributes(
                name: :option,
                params: {config: config}
              )
            )
          }
        )
      end
    end
  end

  describe "#object" do
    context "when params[:of] is a custom type" do
      let(:block) do
        proc do
          config :custom do
            integer :integer
            string :string
          end

          object :option, of: :custom
        end
      end

      it "registers a object option" do
        expect(option).to be_kind_of(NATS::Utils::Config::ObjectOption)
      end

      it "sets options attributes" do
        expect(option).to have_attributes(
          name: :option,
          params: {
            of: :custom,
            config: have_attributes(
              superclass: NATS::Utils::Config,
              schema: include(
                integer: be_kind_of(NATS::Utils::Config::IntegerOption),
                string: be_kind_of(NATS::Utils::Config::StringOption)
              )
            )
          }
        )
      end
    end

    context "when block is given" do
      let(:block) do
        proc do
          object :option do
            integer :integer
            string :string
          end
        end
      end

      it "registers a object option" do
        expect(option).to be_kind_of(NATS::Utils::Config::ObjectOption)
      end

      it "creates a custom type" do
        expect(config).to have_attributes(
          superclass: NATS::Utils::Config,
          schema: include(
            integer: be_kind_of(NATS::Utils::Config::IntegerOption),
            string: be_kind_of(NATS::Utils::Config::StringOption)
          )
        )
      end

      it "sets options attributes" do
        expect(option).to have_attributes(
          name: :option,
          params: {config: config}
        )
      end
    end
  end

  describe "#config" do
    let(:block) do
      proc do
        config :option do
          integer :integer
          string :string
        end
      end
    end

    it "creates a custom type" do
      expect(config).to have_attributes(
        superclass: NATS::Utils::Config,
        schema: include(
          integer: be_kind_of(NATS::Utils::Config::IntegerOption),
          string: be_kind_of(NATS::Utils::Config::StringOption)
        )
      )
    end
  end
end

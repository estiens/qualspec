# frozen_string_literal: true

RSpec.describe Qualspec do
  before { Qualspec.reset! }

  it 'has a version number' do
    expect(Qualspec::VERSION).not_to be_nil
  end

  describe '.configure' do
    it 'yields configuration' do
      Qualspec.configure do |config|
        config.api_url = 'https://test.example.com/v1'
        config.judge_model = 'test-model'
      end

      expect(Qualspec.configuration.api_url).to eq('https://test.example.com/v1')
      expect(Qualspec.configuration.judge_model).to eq('test-model')
    end
  end

  describe '.define_rubric' do
    it 'creates a rubric with criteria' do
      Qualspec.define_rubric :test do
        criterion 'is helpful'
        criterion 'is polite'
      end

      rubric = Qualspec::Rubric.find(:test)
      expect(rubric.criteria).to eq(['is helpful', 'is polite'])
    end
  end

  describe '.define_behavior' do
    it 'creates a behavior with scenarios' do
      Qualspec.define_behavior :test_behavior do
        scenario 'greeting' do
          prompt 'Hello!'
          criterion 'responds warmly'
        end
      end

      behavior = Qualspec::Suite::Behavior.find(:test_behavior)
      expect(behavior.scenarios_list.size).to eq(1)
      expect(behavior.scenarios_list.first.name).to eq('greeting')
    end
  end

  describe '.evaluation' do
    it 'creates an evaluation suite' do
      Qualspec.evaluation 'Test Suite' do
        candidates do
          candidate 'model-a', model: 'provider/model-a'
          candidate 'model-b', model: 'provider/model-b'
        end

        scenario 'test scenario' do
          prompt 'Test prompt'
          criterion 'is correct'
        end
      end

      suite = Qualspec::Suite.find('Test Suite')
      expect(suite.candidates_list.size).to eq(2)
      expect(suite.scenarios_list.size).to eq(1)
    end

    it 'supports behaves_like' do
      Qualspec.define_behavior :shared do
        scenario 'shared test' do
          prompt 'Shared prompt'
          criterion 'works'
        end
      end

      Qualspec.evaluation 'Suite with Behavior' do
        candidates do
          candidate 'test', model: 'test/model'
        end

        behaves_like :shared

        scenario 'custom test' do
          prompt 'Custom'
          criterion 'also works'
        end
      end

      suite = Qualspec::Suite.find('Suite with Behavior')
      expect(suite.scenarios_list.size).to eq(2)
      expect(suite.scenarios_list.map(&:name)).to include('shared test', 'custom test')
    end
  end
end

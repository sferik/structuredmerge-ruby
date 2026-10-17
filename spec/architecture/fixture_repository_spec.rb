# frozen_string_literal: true

RSpec.describe StructuredMerge::FixtureRepository do
  it 'uses the locked fixture revision in the sibling checkout' do
    expect(described_class.checkout_revision).to eq(described_class.revision)
  end

  it 'pins the fixture checkout to a branch and immutable revision' do
    expect(described_class.branch).to eq('main')
    expect(described_class.revision).to match(/\A[0-9a-f]{40}\z/)
  end
end

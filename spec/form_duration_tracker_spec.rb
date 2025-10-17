RSpec.describe FormDurationTracker do
  it "has a version number" do
    expect(FormDurationTracker::VERSION).not_to be nil
  end

  it "provides controller and model concerns" do
    expect(FormDurationTracker::ControllerConcern).to be_a(Module)
    expect(FormDurationTracker::ModelConcern).to be_a(Module)
  end
end

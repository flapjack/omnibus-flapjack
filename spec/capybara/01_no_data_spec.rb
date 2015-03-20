require 'capybara_spec_helper'

describe "Test Flapjack before data is added", :type => :feature do
  after :each do
    links = [ 'Summary', 'Entities', 'Failing Entities', 'Checks', 'Failing Checks', 'Contacts', 'Internal Statistics' ]
    links.each { |l| expect(page).to have_content l }
  end

  it "Check Summary Page" do
    visit '/'

    content = [ 'Flapjack', 'entities have failing checks', 'checks are failing', 'Summary' ]
    content.each { |c| expect(page).to have_content c }
  end

  it "Check All Entities" do
    visit '/entities_all'

    content = [ 'Entities', 'failing out of' ]
    content.each { |c| expect(page).to have_content c }
    expect(page).not_to have_content('failing out of 0')
  end

  it "Check Failing Entities" do
    visit '/entities_failing'

    content = [ 'Failing Entities', 'failing out of']
    content.each { |c| expect(page).to have_content c }
    expect(page).not_to have_content('failing out of 0')
  end

  it "All Checks" do
    visit '/checks_all'

    content = [ 'Checks', 'failing out of',
      'Entity', 'Check', 'State', 'Summary', 'Last State Change', 'Last Update', 'Last Notification',
      'SSH', 'Current Users'
    ]
    content.each { |c| expect(page).to have_content c }
    expect(page).not_to have_content('failing out of 0')
  end

  it "Check Failing Checks" do
    visit '/checks_failing'

    content = [ 'Failing Checks', 'failing out of',
      'Entity', 'Check', 'State', 'Summary', 'Last State Change', 'Last Update', 'Last Notification'
    ]
    content.each { |c| expect(page).to have_content c }
    expect(page).not_to have_content('failing out of 0')
  end

  it "Check Contacts" do
    visit '/contacts'
    wait_for_ajax
    content = [ 'Contacts', 'No contacts' ]
    content.each { |c| expect(page).to have_content c }

    expect(page).to have_link 'Edit contacts'
    click_link 'Edit contacts'
    content = [ 'First Name', 'Last Name', 'Actions' ]
    content.each { |c| expect(page).to have_content c }
  end

  it "Check Internal Statistics"
end

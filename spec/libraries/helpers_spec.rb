# Encoding: UTF-8

require 'ax_elements'
require_relative '../spec_helper'
require_relative '../../libraries/helpers'

describe MacAppStoreCookbook::Helpers do
  let(:app_name) { 'Some App' }

  before(:each) do
    allow(described_class).to receive(:sleep).and_return(true)
  end

  describe '#wait_for_install' do
    let(:timeout) { 10 }
    let(:search) { nil }
    let(:app_page) { double(main_window: double(search: search)) }

    before(:each) do
      allow(described_class).to receive(:app_page).and_return(app_page)
    end

    context 'a successful install' do
      let(:search) { true }

      it 'returns true' do
        expect(described_class.wait_for_install(app_name, timeout)).to eq(true)
      end
    end

    context 'an install timeout' do
      let(:search) { nil }

      it 'raises an error' do
        expected = Chef::Exceptions::CommandTimeout
        expect { described_class.wait_for_install(app_name, timeout) }
          .to raise_error(expected)
      end
    end
  end

  describe '#latest_version' do
    let(:version) { '1.2.3' }
    let(:app_page) do
      double(
        main_window: double(static_text: double(parent: double(
          static_text: double(value: version)))
        )
      )
    end

    before(:each) do
      allow(described_class).to receive(:app_page).and_return(app_page)
    end

    it 'returns the version number' do
      expect(described_class.latest_version(app_name)).to eq('1.2.3')
    end
  end

  describe '#install_button' do
    let(:button) { 'i am a button' }
    let(:app_page) do
      double(main_window: double(web_area: double(group: double(group: double(
        button: button
      )))))
    end

    before(:each) do
      allow(described_class).to receive(:app_page).and_return(app_page)
    end

    it 'returns the install button' do
      expect(described_class.install_button(app_name)).to eq(button)
    end
  end

  describe '#app_page' do
    let(:purchased?) { true }
    let(:press) { true }
    let(:row) { double(link: 'link') }
    let(:app_store) { 'the app store' }

    before(:each) do
      [:purchased?, :press, :row, :app_store].each do |m|
        allow(described_class).to receive(m).and_return(send(m))
      end
    end

    context 'purchased app' do
      let(:purchased?) { true }

      it 'presses the app link' do
        expect(described_class).to receive(:press).with('link')
        described_class.app_page(app_name)
      end

      it 'returns the app store object' do
        expect(described_class.app_page(app_name)).to eq(app_store)
      end
    end

    context 'not purchased app' do
      let(:purchased?) { false }

      it 'raises an error' do
        expected = Chef::Exceptions::Application
        expect { described_class.app_page(app_name) }.to raise_error(expected)
      end
    end
  end

  describe '#purchased?' do
    let(:row) { nil }

    before(:each) { allow(described_class).to receive(:row).and_return(row) }

    context 'app present in Purchases menu' do
      let(:row) { 'a row' }

      it 'returns true' do
        expect(described_class.purchased?(app_name)).to eq(true)
      end
    end

    context 'app not present in Purchases menu' do
      let(:row) { nil }

      it 'returns false' do
        expect(described_class.purchased?(app_name)).to eq(false)
      end
    end
  end

  describe '#row' do
    let(:search) { nil }
    let(:main_window) { double }
    let(:purchases) { double(main_window: main_window) }

    before(:each) do
      allow(described_class).to receive(:purchases).and_return(purchases)
      allow(main_window).to receive(:search)
        .with(:row, link: { title: app_name }).and_return(search)
    end

    context 'a purchased app' do
      let(:search) { 'some row' }

      it 'returns the app row' do
        expect(described_class.row(app_name)).to eq('some row')
      end
    end

    context 'a non-purchased app' do
      let(:search) { nil }

      it 'returns nil' do
        expect(described_class.row(app_name)).to eq(nil)
      end
    end
  end

  describe '#purchases' do
    let(:signed_in?) { true }
    let(:main_window) { double }
    let(:app_store) { double(main_window: main_window, ancestry: []) }

    before(:each) do
      %i(set_focus_to wait_for select_menu_item).each do |m|
        allow(described_class).to receive(m).and_return(m)
      end
      %i(signed_in? app_store).each do |m|
        allow(described_class).to receive(m).and_return(send(m))
      end
      allow(main_window).to receive(:search).with(:link, title: 'sign in')
        .and_return(nil)
    end

    context 'user not signed in' do
      let(:signed_in?) { false }

      it 'raises an exception' do
        expected = Chef::Exceptions::ConfigurationError
        expect { described_class.purchases }.to raise_error(expected)
      end
    end

    context 'user signed in' do
      let(:signed_in?) { true }

      it 'selects Purchases from the dropdown menu'do
        expect(described_class).to receive(:select_menu_item)
          .with(app_store, 'Store', 'Purchases')
        described_class.purchases
      end

      it 'waits for the window group to load' do
        expect(described_class).to receive(:wait_for)
          .with(:group, ancestor: app_store, id: 'purchased')
          .and_return(true)
        described_class.purchases
      end

      it 'returns the App Store object' do
        expect(described_class.purchases).to eq(app_store)
      end
    end

    context 'purchases list loading timeout' do
      before(:each) do
        allow(described_class).to receive(:wait_for)
          .with(:group, ancestor: app_store, id: 'purchased')
          .and_return(nil)
      end

      it 'raises an exception' do
        expected = Chef::Exceptions::CommandTimeout
        expect { described_class.purchases }.to raise_error(expected)
      end
    end
  end

  describe '#sign_in' do
    let(:username) { 'some_user' }
    let(:password) { 'some_password' }
    let(:username_field) { 'a username text box' }
    let(:password_field) { 'a password text box' }
    let(:sign_in_button) { 'a sign in button' }
    let(:signed_in?) { true }
    let(:app_store) { 'dummy data' }

    before(:each) do
      %i(
        username_field password_field sign_in_button signed_in? app_store
      ).each do |m|
        allow(described_class).to receive(m).and_return(send(m))
      end
      %i(select_menu_item sleep set press).each do |m|
        allow(described_class).to receive(m).and_return(true)
      end
    end

    context 'user already signed in' do
      let(:signed_in?) { true }

      it 'returns immediately' do
        expect(described_class).not_to receive(:select_menu_item)
        described_class.sign_in(username, password)
      end
    end

    context 'user not signed in' do
      let(:signed_in?) { false }

      it 'selects the Sign In menu' do
        expect(described_class).to receive(:select_menu_item)
          .with(app_store, 'Store', 'Sign In…')
        described_class.sign_in(username, password)
      end

      it 'waits for the Sign In menu to load' do
        pending
        expect(described_class).to receive(:wait_for)
        described_class.sign_in(username, password)
      end

      it 'enters Apple ID information' do
        expect(described_class).to receive(:set).with(username_field, username)
        described_class.sign_in(username, password)
      end

      it 'enters Password information' do
        expect(described_class).to receive(:set).with(password_field, password)
        described_class.sign_in(username, password)
      end

      it 'presses the Sign In button' do
        expect(described_class).to receive(:press).with(sign_in_button)
        described_class.sign_in(username, password)
      end
    end
  end

  describe '#sign_in_button' do
    let(:button) { 'a button' }
    let(:sheet) { double }
    let(:app_store) { double(main_window: double(sheet: sheet)) }

    before(:each) do
      allow(sheet).to receive(:button).with(title: 'Sign In')
        .and_return(button)
      allow(described_class).to receive(:app_store).and_return(app_store)
    end

    it 'returns the Sign In button' do
      expect(described_class.sign_in_button).to eq(button)
    end
  end

  describe '#username_field' do
    let(:text_field) { 'text field' }
    let(:static_text) { 'static text' }
    let(:sheet) { double }
    let(:app_store) { double(main_window: double(sheet: sheet)) }

    before(:each) do
      allow(sheet).to receive(:static_text).with(value: 'Apple ID ')
        .and_return(static_text)
      allow(sheet).to receive(:text_field).with(title_ui_element: static_text)
        .and_return(text_field)
      allow(described_class).to receive(:app_store).and_return(app_store)
    end

    it 'returns the Apple ID text field' do
      expect(described_class.username_field).to eq(text_field)
    end
  end

  describe '#password_field' do
    let(:secure_text_field) { 'secure text field' }
    let(:static_text) { 'static text' }
    let(:sheet) { double }
    let(:app_store) { double(main_window: double(sheet: sheet)) }

    before(:each) do
      allow(sheet).to receive(:static_text).with(value: 'Password')
        .and_return(static_text)
      allow(sheet).to receive(:secure_text_field)
        .with(title_ui_element: static_text).and_return(secure_text_field)
      allow(described_class).to receive(:app_store).and_return(app_store)
    end

    it 'returns the Password text field' do
      expect(described_class.password_field).to eq(secure_text_field)
    end
  end

  describe '#signed_in?' do
    let(:signed_in?) { false }
    let(:search) { signed_in? ? 'some data' : nil }
    let(:menu_bar_item) { double }
    let(:app_store) { double }

    before(:each) do
      allow(menu_bar_item).to receive(:search)
        .with(:menu_item, title: 'Sign Out').and_return(search)
      allow(app_store).to receive(:menu_bar_item).with(title: 'Store')
        .and_return(menu_bar_item)
      allow(described_class).to receive(:app_store).and_return(app_store)
    end

    context 'user not signed in' do
      let(:signed_in?) { false }

      it 'returns false' do
        expect(described_class.signed_in?).to eq(false)
      end
    end

    context 'user signed in' do
      let(:signed_in?) { true }

      it 'returns true' do
        expect(described_class.signed_in?).to eq(true)
      end
    end
  end

  describe '#quit!' do
    let(:app_store) { double(terminate: true) }
    let(:running?) { false }

    before(:each) do
      allow(described_class).to receive(:app_store).and_return(app_store)
      allow(described_class).to receive(:running?).and_return(running?)
    end

    context 'App Store not running' do
      let(:running?) { false }

      it 'does not try to quit' do
        expect(app_store).not_to receive(:terminate)
        described_class.quit!
      end
    end

    context 'App Store running' do
      let(:running?) { true }

      it 'quits' do
        expect(app_store).to receive(:terminate)
        described_class.quit!
      end
    end
  end

  describe '#app_store' do
    let(:app_store) { 'some object' }

    before(:each) do
      allow(AX::Application).to receive(:new).with('com.apple.appstore')
        .and_return(app_store)
      allow(described_class).to receive(:wait_for).and_return(true)
    end

    it 'returns an AX::Application object' do
      expect(described_class.app_store).to eq('some object')
    end

    it 'waits for the Purchases menu to load' do
      expect(described_class).to receive(:wait_for)
        .with(:menu_item, ancestor: app_store, title: 'Purchases')
        .and_return(true)
      described_class.app_store
    end

    context 'Purchases menu loading timeout' do
      before(:each) do
        allow(described_class).to receive(:wait_for)
          .with(:menu_item, ancestor: app_store, title: 'Purchases')
          .and_return(nil)
      end

      it 'raises an exception' do
        expected = Chef::Exceptions::CommandTimeout
        expect { described_class.app_store }.to raise_error(expected)
      end
    end
  end

  describe '#running?' do
    let(:running_applications) { [] }

    before(:each) do
      allow(NSRunningApplication)
        .to receive(:runningApplicationsWithBundleIdentifier)
        .with('com.apple.appstore').and_return(running_applications)
    end

    context 'App Store not running' do
      let(:running_applications) { [] }

      it 'returns false' do
        expect(described_class.running?).to eq(false)
      end
    end

    context 'App Store running' do
      let(:running_applications) { %w(some_app) }

      it 'returns true' do
        expect(described_class.running?).to eq(true)
      end
    end
  end
end
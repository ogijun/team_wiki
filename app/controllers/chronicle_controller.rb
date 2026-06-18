class ChronicleController < ApplicationController
  def index
    @entries = Chronicle.entries
  end
end

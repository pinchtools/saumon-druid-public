# frozen_string_literal: true

class ConversationsController < ApplicationController
  before_action :set_session_id
  before_action :set_conversation, only: [ :show, :destroy ]

  def index
    @conversations = Conversation.recent.limit(50)
    @conversation = @conversations.first
  end

  def show
    @conversations = Conversation.recent.limit(50)
  end

  def create
    @conversation = Conversation.create!(
      session_id: Current.session_id,
      status: Conversation::STATUS_ACTIVE
    )

    redirect_to @conversation
  end

  def destroy
    @conversation.destroy

    respond_to do |format|
      format.html { redirect_to conversations_path }
      format.turbo_stream
    end
  end

  private

  def set_session_id
    session[:session_id] ||= SecureRandom.uuid
    Current.session_id = session[:session_id]
  end

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end
end

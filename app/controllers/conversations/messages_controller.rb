# frozen_string_literal: true

module Conversations
  class MessagesController < ApplicationController
    before_action :set_conversation

    def create
      @user_message = @conversation.add_user_message(message_params[:content])
      @assistant_message = @conversation.add_assistant_message

      respond_to do |format|
        format.turbo_stream
      end
    end

    private

    def set_conversation
      @conversation = Conversation.find(params[:conversation_id])
    end

    def message_params
      params.require(:message).permit(:content)
    end
  end
end

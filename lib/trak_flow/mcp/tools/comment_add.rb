# frozen_string_literal: true

module TrakFlow
  module Mcp
    module Tools
      class CommentAdd < BaseTool
        tool_name "comment_add"
        description "Add a comment to a task"

        arguments do
          required(:task_id).filled(:string).description("Task ID")
          required(:body).filled(:string).description("Comment text")
          optional(:author).filled(:string).description("Comment author (default: robot)")
        end

        def call(task_id:, body:, author: "robot")
          self.class.with_database do |db|
            db.find_task!(task_id)

            comment = Models::Comment.new(
              task_id: task_id,
              body: body,
              author: author
            )
            db.add_comment(comment)

            comment.to_h
          end
        end
      end
    end
  end
end

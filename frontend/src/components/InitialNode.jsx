import { memo, useState } from 'react';
import { Handle, Position } from '@xyflow/react';

const InitialNodeComponent = ({ data }) => {
  const [inputValue, setInputValue] = useState('');
  const [submitted, setSubmitted] = useState(false);

  const handleSubmit = (e) => {
    e.preventDefault();
    if (data.onPrompt && inputValue.trim() && !submitted) {
      setSubmitted(true);
      data.onPrompt(inputValue);
      setInputValue('');
    }
  };

  return (
    <div className="w-[576px] p-6 rounded-lg border-2 border-gray-400 bg-white shadow-lg hover:shadow-xl transition-shadow">
      <div className="space-y-4">
        <div className="font-semibold text-gray-900 text-lg">Start Conversation</div>
        <form onSubmit={handleSubmit} className="space-y-3">
          <input
            type="text"
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            placeholder="Enter your first message..."
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-gray-500 focus:border-gray-500 text-gray-900"
            autoFocus
            disabled={submitted}
          />
          <button
            type="submit"
            className="w-full px-4 py-2 bg-gray-900 text-white rounded-md hover:bg-gray-800 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed"
            disabled={!inputValue.trim() || submitted}
          >
            {submitted ? 'Starting...' : 'Start Conversation'}
          </button>
        </form>
      </div>
      
      <Handle 
        type="source" 
        position={Position.Bottom} 
        id="source"
        className="w-3 h-3 bg-gray-900 !opacity-100" 
      />
    </div>
  );
};

InitialNodeComponent.displayName = 'InitialNode';

export default memo(InitialNodeComponent);

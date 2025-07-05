import { memo, useState } from 'react';
import { Handle, Position } from '@xyflow/react';

const InteractionNodeComponent = ({ data }) => {
  const [inputValue, setInputValue] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    if (data.onPrompt) {
      data.onPrompt(inputValue);
    }
    setInputValue('');
  };

  return (
    <div className="min-w-[300px] p-6 rounded-lg border-2 border-blue-400 bg-white shadow-lg hover:shadow-xl transition-shadow">
      <Handle type="target" position={Position.Top} className="w-3 h-3 bg-blue-500" />
      
      <div className="space-y-4">
        <div className="font-semibold text-gray-900 text-lg">{data.label}</div>
        <div className="text-sm text-gray-600 space-y-2">
          <div>
            <div className="font-medium text-blue-600">Prompt:</div>
            <div className="mt-1 p-2 bg-gray-50 rounded">{data.prompt}</div>
          </div>
          <div>
            <div className="font-medium text-blue-600">Response:</div>
            <div className="mt-1 p-2 bg-gray-50 rounded">{data.content}</div>
          </div>
          <form onSubmit={handleSubmit} className="mt-4">
            <input
              type="text"
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              placeholder="Enter your prompt..."
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-gray-900"
              autoFocus
            />
            <button
              type="submit"
              className="mt-2 w-full px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition-colors"
            >
              Generate
            </button>
          </form>
        </div>
      </div>
      
      <Handle type="source" position={Position.Bottom} className="w-3 h-3 bg-blue-500" />
    </div>
  );
};

InteractionNodeComponent.displayName = 'InteractionNode';

export default memo(InteractionNodeComponent); 
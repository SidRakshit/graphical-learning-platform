import { useState, useMemo } from 'react';
import { ReactFlowProvider, ReactFlow } from '@xyflow/react';
import {
  Controls,
  Background,
  useNodesState,
  useEdgesState,
  Position,
  MarkerType,
  Panel,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import InteractionNode from './components/InteractionNode.jsx';

const API_BASE_URL = '/api';

const nodeTypes = {
  default: InteractionNode,
};

const LoginModal = ({ onLogin }) => {
  const [inputValue, setInputValue] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    if (inputValue.trim()) {
      const newUser = {
        id: inputValue.trim().toLowerCase().replace(/\s+/g, '-'),
        name: inputValue.trim()
      };
      onLogin(newUser);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
      <div className="bg-white p-8 rounded-lg shadow-xl max-w-md w-full">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Welcome to Interaction Flow</h2>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="username" className="block text-sm font-medium text-gray-700">
              Enter your name
            </label>
            <input
              type="text"
              id="username"
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-gray-900"
              placeholder="Your name"
              required
            />
          </div>
          <button
            type="submit"
            className="w-full px-4 py-2 bg-blue-500 text-white rounded-md hover:bg-blue-600 transition-colors"
          >
            Start
          </button>
        </form>
      </div>
    </div>
  );
};

const Flow = () => {
  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [user, setUser] = useState(null);

  const handleLogin = async (newUser) => {
    setUser(newUser);
    try {
      console.log('Sending request to:', `${API_BASE_URL}/interaction-nodes/start`);
      console.log('Request headers:', {
        'Content-Type': 'application/json',
        'x-user-id': newUser.id,
      });
      console.log('Request body:', {
        user_prompt: 'Start a new interaction',
        summary_title: 'Initial Interaction'
      });

      const response = await fetch(`${API_BASE_URL}/interaction-nodes/start`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': newUser.id,
          'Accept': 'application/json',
        },
        mode: 'cors',
        body: JSON.stringify({
          user_prompt: 'Start a new interaction',
          summary_title: 'Initial Interaction'
        }),
      });

      console.log('Response status:', response.status);
      console.log('Response headers:', Object.fromEntries(response.headers.entries()));

      if (!response.ok) {
        const errorData = await response.json().catch(() => null);
        console.error('API Error Response:', errorData);
        throw new Error(`HTTP error! status: ${response.status}, message: ${errorData?.detail || 'Unknown error'}`);
      }

      const data = await response.json();
      console.log('Initial node data:', data);
      
      if (!data || !data.node_id) {
        throw new Error('Invalid response data: missing node_id');
      }
      
      // Calculate center position
      const centerX = window.innerWidth / 2 - 150;
      const centerY = window.innerHeight / 2 - 100;
      
      const newNode = createNode(data, { x: centerX, y: centerY });
      console.log('Created new node:', newNode);
      
      setNodes([newNode]);
      setEdges([]);
    } catch (error) {
      console.error('Error starting interaction:', error);
      // Show more detailed error to user
      alert(`Failed to create initial interaction: ${error.message}. Please try again.`);
    }
  };

  const createNode = (data, position) => ({
    id: data.node_id,
    type: 'default',
    position,
    data: {
      label: data.summary_title || 'New Interaction',
      content: data.llm_response,
      prompt: data.user_prompt,
      onPrompt: async (prompt) => {
        if (!user) return;
        
        try {
          const response = await fetch(`${API_BASE_URL}/interaction-nodes/${data.node_id}/branch`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'x-user-id': user.id,
            },
            body: JSON.stringify({
              user_prompt: prompt,
            }),
          });

          const newData = await response.json();
          
          const newNode = createNode(newData, {
            x: position.x,
            y: position.y + 200,
          });

          const newEdge = createEdge(data.node_id, newData.node_id);

          setNodes(nds => [...nds, newNode]);
          setEdges(eds => [...eds, newEdge]);
        } catch (error) {
          console.error('Error creating branch:', error);
        }
      }
    },
    sourcePosition: Position.Bottom,
    targetPosition: Position.Top,
  });

  const createEdge = (source, target) => ({
    id: `${source}-${target}`,
    source,
    target,
    type: 'smoothstep',
    markerEnd: {
      type: MarkerType.ArrowClosed,
    },
  });

  if (!user) {
    return <LoginModal onLogin={handleLogin} />;
  }

  return (
    <div className="h-screen">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        nodeTypes={nodeTypes}
        fitView
      >
        <Background />
        <Controls />
        <Panel position="top-right" className="bg-white p-4 rounded-lg shadow-lg">
          <div className="flex items-center gap-4">
            <span className="text-gray-600">Welcome, {user.name}</span>
            <button
              onClick={() => handleLogin(user)}
              className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              New Interaction
            </button>
          </div>
        </Panel>
      </ReactFlow>
    </div>
  );
};

const App = () => {
  return (
    <ReactFlowProvider>
      <Flow />
    </ReactFlowProvider>
  );
};

export default App;

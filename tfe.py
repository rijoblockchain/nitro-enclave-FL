import numpy as np
import tf_encrypted as tfe

# Define private model with tfe Keras
tfe_model = tfe.keras.Sequential([
            tfe.keras.layers.Conv2D(16, 8,
                                   strides=2,
                                   padding='same',
                                   activation='relu',
                                   batch_input_shape=input_shape),
            tfe.keras.layers.AveragePooling2D(2, 1),
            tfe.keras.layers.Conv2D(32, 4,
                                   strides=2,
                                   padding='valid',
                                   activation='relu'),
            tfe.keras.layers.AveragePooling2D(2, 1),
            tfe.keras.layers.Flatten(),
            tfe.keras.layers.Dense(32, activation='relu'),
            tfe.keras.layers.Dense(10, name='logit')
      ])

# load numpy file with trained weights
numpy_weights = np.load('numpy_weights.npy')

# Set tfe model weights
tfe_model.set_weights(numpy_weights)